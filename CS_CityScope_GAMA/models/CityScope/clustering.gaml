/**
* Name: clustering
* Based on the internal empty template. 
* Author: Juan Múgica
* Tags: 
*/


model clustering

import "./Agents.gaml"
import "./Parameters.gaml"

global {
	date starting_date <- #now;
	//---------------------------------------------------------Performance Measures-----------------------------------------------------------------------------
	//-------------------------------------------------------------------Necessary Variables--------------------------------------------------------------------------------------------------

    	
	// GIS FILES


	geometry shape <- envelope(bound_shapefile);
	graph roadNetwork;
	list<int> chargingStationLocation;
  	

    	// ---------------------------------------Species Creation----------------------------------------------
    init {
    	// ---------------------------------------Buildings----------------------------------------------
	    //Juan: Adapt this depending on GIS data
	    /*create building from: buildings_shapefile with: [type::string(read ("Category"))] {
			if(type!="Office" and type!="Residential"){
				type <- "Other";
			}
		}
	    
	    list<building> residential_buildings <- building where (each.type="Residential");
	    list<building> office_buildings <- building where (each.type="Office");*/
	    create building from: buildings_shapefile with: [type::string(read ("Usage"))] {
			if(type!="O" and type!="R"){
				type <- "Other";
			}
		}
	        

	    list<building> residential_buildings <- building where (each.type="R");
	    list<building> office_buildings <- building where (each.type="O");
	    
		// ---------------------------------------The Road Network----------------------------------------------
		    
		create pheromoneRoad from: roads_shapefile{
			pheromone <- 0.0;
		}		
		roadNetwork <- as_edge_graph(pheromoneRoad) ;   
		// Next move to the shortest path between each point in the graph
		matrix allPairs <- all_pairs_shortest_path (roadNetwork);    
	    
		// -------------------------------------Location of the charging stations----------------------------------------   

	    //from docking locations to closest intersection
	    list<int> tmpDist;	    
  
	    
	    /*//Juan: for docking stations obtained from file
	    list<int> dockingLocation;
	    create docking from: dockingStations ;
	    loop station from:0 to:length(docking)-1 {
	    	tmpDist <- [];
	    	loop vertice from:0 to:length(roadNetwork.vertices)-1{
	    		add (point(roadNetwork.vertices[vertice])) distance_to docking[station].location to: tmpDist;
	    	}
	    	loop vertice from:0 to: length(tmpDist)-1{
	    		if(min(tmpDist)=tmpDist[vertice]){
	    			add vertice to: dockingLocation;
	    			break;
	    		}
	    	}
	    }
	    
	    //Asign docking locations the new locations
	    loop station from:0 to:length(docking)-1 {
	    	docking[station].location <- roadNetwork.vertices[dockingLocation[station]];
	    }*/

		loop i from: 0 to: length(roadNetwork.vertices) - 1 {
			create intersection {
				location <- point (roadNetwork.vertices[i]);
			}
		}

		//K-Means		
		//Create a list of list containing for each docking a list composed of its x and y values
		list<list> instances <- intersection collect ([each.location.x, each.location.y]);

		//from the vertices list, create k groups  with the Kmeans algorithm (https://en.wikipedia.org/wiki/K-means_clustering)
		list<list<int>> clusters_kmeans <- list<list<int>>(kmeans(instances, dockingNum));

		//from clustered vertices to centroids locations
		int groupIndex <- 0;
		list<point> coordinatesCentroids <- [];
		loop cluster over: clusters_kmeans {
			groupIndex <- groupIndex + 1;
			list<point> coordinatesVertices <- [];
			loop i over: cluster {
				add point (roadNetwork.vertices[i]) to: coordinatesVertices; 
			}
			add mean(coordinatesVertices) to: coordinatesCentroids;
		}    
	    


		loop centroid from:0 to:length(coordinatesCentroids)-1 {
			tmpDist <- [];
			loop vertices from:0 to:length(roadNetwork.vertices)-1{
				add (point(roadNetwork.vertices[vertices]) distance_to coordinatesCentroids[centroid]) to: tmpDist;
			}	
			loop vertices from:0 to: length(tmpDist)-1{
				if(min(tmpDist)=tmpDist[vertices]){
					add vertices to: chargingStationLocation;
					break;
				}
			}	
		}
	    

	    loop i from: 0 to: length(chargingStationLocation) - 1 {
			create chargingStation{
				location <- point(roadNetwork.vertices[chargingStationLocation[i]]);
			}
		}
		
	    
		// -------------------------------------------The Bikes -----------------------------------------
		create bike number:bikeNum{						
			location <- point(one_of(roadNetwork.vertices)); 
			target <- location; 
			source <- location;
			picking <- false;
			lowBattery <- false;
			pheromoneToDiffuse <- 0.0;
			pheromoneMark <- 0.0;
			batteryLife <- rnd(maxBatteryLife);
			//Juan: change to random when update battery behavior
			//speedDist <- rnd(maxSpeedDist);
			speedDist <- maxSpeedDist;
		}
	    
		// -------------------------------------------The People -----------------------------------------
	    create people number: nb_people {
	        start_work <- rnd (min_work_start, max_work_start);
	        end_work <- rnd(min_work_end, max_work_end);
	        living_place <- one_of(residential_buildings) ;
	        working_place <- one_of(office_buildings) ;
	        objective <- "resting";
	        location <- any_location_in (one_of (residential_buildings));
	    }
	 	// ----------------------------------The RFIDs tag on each road intersection------------------------
		loop i from: 0 to: length(roadNetwork.vertices) - 1 {
			create tagRFID{ 								
				id <- i;
				//checked <- false;					
				location <- point(roadNetwork.vertices[i]); 
				pheromones <- [0.0,0.0,0.0,0.0,0.0];
				pheromonesToward <- neighbors_of(roadNetwork,roadNetwork.vertices[i]);  //to know what edge is related to that amount of pheromone
				
				// Find the closest chargingPoint and set towardChargingStation and distanceToChargingStation
				ask chargingStation closest_to self {
					myself.distanceToChargingStation <- int(point(roadNetwork.vertices[i]) distance_to self.location);
					loop y from: 0 to: length(chargingStationLocation) - 1 {
						if (point(roadNetwork.vertices[chargingStationLocation[y]]) = self.location){
							//Assign next vertice to closest charging  station
							myself.towardChargingStation <- point(roadNetwork.vertices[allPairs[chargingStationLocation[y],i]]);
							//Juan: I think this is if next node is already charging station
							if (myself.towardChargingStation=point(roadNetwork.vertices[i])){
								myself.towardChargingStation <- point(roadNetwork.vertices[chargingStationLocation[y]]);
							}
							break;
						}				
					}					
				}				
				type <- 'roadIntersection';				
				loop y from: 0 to: length(chargingStationLocation) - 1 {
					if (i=chargingStationLocation[y]){
						type <- 'chargingStation&roadIntersection';
					}
				}			
			}
		} 
    }
}




experiment clustering type: gui {
    parameter "Shapefile for the buildings:" var: buildings_shapefile category: "GIS" ;
    parameter "Shapefile for the roads:" var: roads_shapefile category: "GIS" ;
    parameter "Shapefile for the bounds:" var: bound_shapefile category: "GIS" ;
    parameter "Number of people agents:" var: nb_people category: "People" ;
    parameter "Number of charging points:" var: dockingNum category: "Docking" ;
    parameter "Earliest hour to start work" var: min_work_start category: "People" min: 2 max: 8;
    parameter "Latest hour to start work" var: max_work_start category: "People" min: 8 max: 12;
    parameter "Earliest hour to end work" var: min_work_end category: "People" min: 12 max: 16;
    parameter "Latest hour to end work" var: max_work_end category: "People" min: 16 max: 23;
    parameter "minimal speed" var: min_speed category: "People" min: 0.1 #km/#h ;
    parameter "maximal speed" var: max_speed category: "People" max: 10 #km/#h;
        
    output {
		display city_display type:opengl background: #black draw_env: false{	
			species building aspect: type ;
			species pheromoneRoad aspect: base ;
			//species tagRFID aspect: base ;
			species people aspect: base ;
			species chargingStation aspect: base ;
			species bike aspect: realistic ;
			species ride aspect: realistic ; 
			graphics "text" {
				draw "day" + string(current_date.day) + " - " + string(current_date.hour) + "h" color: #white font: font("Helvetica", 25, #italic) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
				draw imageRaster size: 40 #px at: {world.shape.width * 0.98, world.shape.height * 0.95};
			}
		}
    }
}