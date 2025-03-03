/**
* Name: clustering
* Based on the internal empty template. 
* Author: Juan Múgica
* Tags: 
*/


model clustering

import "./Agents.gaml"
import "./Loggers.gaml"
import "./Parameters.gaml"

global {
	date starting_date <- #now;
	//---------------------------------------------------------Performance Measures-----------------------------------------------------------------------------
	//-------------------------------------------------------------------Necessary Variables--------------------------------------------------------------------------------------------------

	// GIS FILES
	geometry shape <- envelope(bound_shapefile);
	graph roadNetwork;
	list<int> chargingStationLocation;
	
	
	
    // ---------------------------------------Agent Creation----------------------------------------------
    init {
    	// ---------------------------------------Buildings----------------------------------------------
	    create building from: buildings_shapefile with: [type:string(read ("Usage"))] {
			if(type!="O" and type!="R"){ type <- "Other"; }
		}
	        
	    list<building> residentialBuildings <- building where (each.type="R");
	    list<building> officeBuildings <- building where (each.type="O");
	    
		// ---------------------------------------The Road Network----------------------------------------------
		create road from: roads_shapefile;
		
		roadNetwork <- as_edge_graph(road) ;   
		// Next move to the shortest path between each point in the graph
		matrix allPairs <- all_pairs_shortest_path (roadNetwork);    
	    
		// -------------------------------------Location of the charging stations----------------------------------------   
	    //from docking locations to closest intersection
	    list<int> tmpDist;

		loop vertex over: roadNetwork.vertices {
			create tagRFID {
				id <- roadNetwork.vertices index_of vertex;
				location <- point(vertex);
			}
		}

		//K-Means		
		//Create a list of x,y coordinate for each intersection
		list<list> instances <- tagRFID collect ([each.location.x, each.location.y]);

		//from the vertices list, create k groups  with the Kmeans algorithm (https://en.wikipedia.org/wiki/K-means_clustering)
		list<list<int>> kmeansClusters <- list<list<int>>(kmeans(instances, numDockingStations));

		//from clustered vertices to centroids locations
		int groupIndex <- 0;
		list<point> coordinatesCentroids <- [];
		loop cluster over: kmeansClusters {
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
		create bike number:numBikes{						
			location <- point(one_of(roadNetwork.vertices));
			nextTag <- tagRFID( location );
			lastTag <- nextTag;
			
			pheromoneToDiffuse <- 0.0;
			pheromoneMark <- 0.0;
			//Battery life random but not starting on 0. Now 75% of MaxBatteryLife
			batteryLife <- rnd(maxBatteryLife*0.75,maxBatteryLife);
			speed <- BikeSpeed;
			distancePerCycle <- step * speed;
			
//			write "cycle: " + cycle + ", " + string(self) + " created with batteryLife " + self.batteryLife;
		}
	    
		// -------------------------------------------The People -----------------------------------------
	    create people number: numPeople {
	        start_work <- rnd (workStartMin, workStartMax);
	        end_work <- rnd(workEndMin, workEndMax);
	        living_place <- one_of(residentialBuildings) ;
	        working_place <- one_of(officeBuildings) ;
	        location <- any_location_in(living_place);
    		 
	    }
	 	// ----------------------------------The RFIDs tag on each road intersection------------------------
		
		ask tagRFID {
			location <- point(roadNetwork.vertices[id]); 
			pheromoneMap <- map( neighbors_of(roadNetwork,roadNetwork.vertices[id]) collect (each::0.0) );  //to know what edge is related to that amount of pheromone
			
			// Find the closest chargingPoint and set towardChargingStation and distanceToChargingStation
			nearestChargingStation <- chargingStation closest_to self;
			distanceToChargingStation <- int( self distance_to nearestChargingStation );
		}
		
		
		write "FINISH INITIALIZATION";
    }
	
	
	
	
		
	list<bike> availableBikes(people person) {
		return bike where (each.availableForRide() and (each distance_to person) <= rideDistance);
	}

	
	bool requestBike(people person) { //returns true if bike is available
		list<bike> candidates <- availableBikes(person);
		if empty(availableBikes(person)) {
			return false; //Here we would consider wait time and return false if too high. Currently un-implemented
		}
		map<bike, float> costs <- map( candidates collect(each::bikeCost(person, each)));
		float minCost <- min(costs.values);
		bike b <- costs.keys[ costs.values index_of minCost ];
		
		//Ask for pickup
		ask b {
			do pickUp(person);
		}
		ask person {
			do ride(b);
		}
		
		return true;
	}
	
	float bikeCost(people person, bike b) {
		//We like the bike less if its far, more if it has power
		//BatteryLife normalized to make this system agnostic to maxBatteryLife
		return (person distance_to b) - (b.batteryLife / maxBatteryLife)*200;
	}
}



//TODO: fill this out with tests to verify that all functions work properly
//Also, figure out how to even use tests
species Tester {
	setup {
		
	}
	
	test  test1 {
		
	}
}
//TODO fill this out with benchmarks for each function, to be evaluated at different populations
experiment benchmarks { 
	init {
		benchmark message: 'arithmetic operation' repeat: 5 {
			//benchmark code will be run 'repeat' times, and report min,max,avg runtime
			int a <- int(1*54.2);
		}
	}
}

















experiment clustering type: gui {
	parameter var: numBikes init: 135;
	parameter var: numPeople init: 350;
    output {
		display city_display type:opengl background: #black draw_env: false{	
			species tagRFID aspect: base ;
			species building aspect: type ;
			species road aspect: base ;
			species people aspect: base ;
			species chargingStation aspect: base ;
			species bike aspect: realistic ;
			graphics "text" {
				draw "day" + string(current_date.day) + " - " + string(current_date.hour) + "h" color: #white font: font("Helvetica", 25, #italic) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
				draw imageRaster size: 40 #px at: {world.shape.width * 0.98, world.shape.height * 0.95};
			}
		}
    }
}

experiment clustering_headless {
	parameter var: numBikes init: 135;
	parameter var: numPeople init: 350;
}

experiment one_person type: gui {
	parameter var: numBikes init: 0;
	parameter var: numPeople init: 1;
	
    output {
		display city_display type:opengl background: #black draw_env: false{	
			species tagRFID aspect: base ;
			species building aspect: type ;
			species road aspect: base ;
			species people aspect: base ;
			species chargingStation aspect: base ;
			species bike aspect: realistic ;
			graphics "text" {
				draw "day" + string(current_date.day) + " - " + string(current_date.hour) + "h" color: #white font: font("Helvetica", 25, #italic) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
				draw imageRaster size: 40 #px at: {world.shape.width * 0.98, world.shape.height * 0.95};
			}
		}
    }
}

experiment one_each type: gui {
	parameter var: numBikes init: 1;
	parameter var: numPeople init: 1;
    output {
		display city_display type:opengl background: #white draw_env: false{	
			species tagRFID aspect: base ;
			species building aspect: type ;
			species road aspect: base ;
			species people aspect: base ;
			species chargingStation aspect: base ;
			species bike aspect: realistic ;
			graphics "text" {
				draw "day" + string(current_date.day) + " - " + string(current_date.hour) + "h" color: #white font: font("Helvetica", 25, #italic) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
				draw imageRaster size: 40 #px at: {world.shape.width * 0.98, world.shape.height * 0.95};
			}
		}
    }
}
experiment one_bike type: gui {
	parameter var: numBikes init: 1;
	parameter var: numPeople init: 0;
	
    output {
		display city_display type:opengl background: #black draw_env: false{	
			species tagRFID aspect: base ;
			species building aspect: type ;
			species road aspect: base ;
			species people aspect: base ;
			species chargingStation aspect: base ;
			species bike aspect: realistic ;
			
			graphics "text" {
				draw "day" + string(current_date.day) + " - " + string(current_date.hour) + "h" color: #white font: font("Helvetica", 25, #italic) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
				draw imageRaster size: 40 #px at: {world.shape.width * 0.98, world.shape.height * 0.95};
			}
		}
    }
}

experiment just_a_lot_of_bikes type: gui {
	parameter var: numBikes init: 20;
	parameter var: numPeople init: 0;
	
    output {
		display city_display type:opengl background: #black draw_env: false{	
//			species tagRFID aspect: base;
			species building aspect: type;
			species road aspect: base;
			species people aspect: base;
			species chargingStation aspect: base;
			species bike aspect: realistic;
			
			graphics "text" {
				draw "day" + string(current_date.day) + " - " + string(current_date.hour) + "h" color: #white font: font("Helvetica", 25, #italic) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
				draw imageRaster size: 40 #px at: {world.shape.width * 0.98, world.shape.height * 0.95};
			}
		}
    }
}
experiment one_each_headless {
	parameter var: numBikes init: 1;
	parameter var: numPeople init: 1;
}
experiment one_bike_headless {
	parameter var: numBikes init: 1;
	parameter var: numPeople init: 0;
}
