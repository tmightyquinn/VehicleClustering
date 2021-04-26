/**
* Name: clustering
* Based on the internal empty template. 
* Author: Juan Múgica
* Tags: 
*/


model clustering

global {
    float step <- 10 #mn;
    int current_hour update: (time / #hour) mod 24;
	//Implement a reflex to update current day. See City Scope Main. TBD
	int current_day <- 0;
	date starting_date <- date("2021-04-23-00-00-00");
	
 	string cityScopeCity<-"clustering";
	string cityGISFolder <- "./../../includes/City/"+cityScopeCity;
	// GIS FILES
	file shape_file_bounds <- file(cityGISFolder + "/BOUNDARY_CityBoundary.shp");
	file shape_file_buildings <- file(cityGISFolder + "/CDD_LandUse.shp");
	file shape_file_roads <- file(cityGISFolder + "/BASEMAP_Roads.shp");
	file dockingStations <- file(cityGISFolder + "/holaaa");
	file imageRaster <- file('./../../images/gama_black.png');
	geometry shape <- envelope(shape_file_bounds);
    int nb_people <- 100;
    int min_work_start <- 6;
    int max_work_start <- 8;
    int min_work_end <- 16; 
    int max_work_end <- 20; 
    float min_speed <- 1.0 #km / #h;
    float max_speed <- 5.0 #km / #h; 
    graph the_graph;
    //rgb backgroundColor<-#white;
    map<string, rgb>
    color_map <- ["Residence"::#white, "Office"::#gray, "Road"::#black];
    
    init {
    create building from: shape_file_buildings with: [type::string(read ("Category"))] {
        if type="Office" {
        color <- #blue ;
        }
        if type="Residential" {
        color <- #green ;
        }
        }
    
    create road from: shape_file_roads ; 
    the_graph <- as_edge_graph(road);
    
    create docking from: dockingStations ; 
    
    list<building> residential_buildings <- building where (each.type="Residential");
    list<building> office_buildings <- building where (each.type="Residential");
    create people number: nb_people {
        speed <- rnd(min_speed, max_speed);
        start_work <- rnd (min_work_start, max_work_start);
        end_work <- rnd(min_work_end, max_work_end);
        living_place <- one_of(residential_buildings) ;
        working_place <- one_of(office_buildings) ;
        objective <- "resting";
        location <- any_location_in (one_of (residential_buildings));
    }
    
    }
}

species building {
    string type; 
    rgb color <- #black  ;
    
    aspect base {
    draw shape color: color ;
    }
    
    aspect default {
		draw shape color: rgb(50, 50, 50, 125);
	}
    
}

species road  {
    rgb color <- #black ;
    aspect base {
       draw shape color: rgb(125, 125, 125);
    }
}

species docking  {
    rgb color <- #blue ;
    aspect base {
      draw shape color: color ;
    }
}

species people skills:[moving]{
    rgb color <- #yellow ;
    building living_place <- nil ;
    building working_place <- nil ;
    int start_work ;
    int end_work  ;
    string objective ;
    point the_target <- nil ;
    
    reflex time_to_work when: current_date.hour = start_work and objective = "resting"{
    objective <- "working" ;
    the_target <- any_location_in (working_place);
    }
    
    reflex time_to_go_home when: current_date.hour = end_work and objective = "working"{
    objective <- "resting" ;
    the_target <- any_location_in (living_place); 
    }
    
    reflex move when: the_target != nil {
    do goto target: the_target on: the_graph ; 
    if the_target = location {
        the_target <- nil ;
    }
    }
    
    aspect base {
    draw circle(10) color: color border: #black;
    }
}

experiment clustering type: gui {
    parameter "Shapefile for the buildings:" var: shape_file_buildings category: "GIS" ;
    parameter "Shapefile for the roads:" var: shape_file_roads category: "GIS" ;
    parameter "Shapefile for the bounds:" var: shape_file_bounds category: "GIS" ;
    parameter "Number of people agents:" var: nb_people category: "People" ;
    parameter "Earliest hour to start work" var: min_work_start category: "People" min: 2 max: 8;
    parameter "Latest hour to start work" var: max_work_start category: "People" min: 8 max: 12;
    parameter "Earliest hour to end work" var: min_work_end category: "People" min: 12 max: 16;
    parameter "Latest hour to end work" var: max_work_end category: "People" min: 16 max: 23;
    parameter "minimal speed" var: min_speed category: "People" min: 0.1 #km/#h ;
    parameter "maximal speed" var: max_speed category: "People" max: 10 #km/#h;
        
    output {
    //display city_display type:opengl background: #black draw_env: false{
    display city_display type:opengl draw_env: false{	
        species building aspect: default ;
        species road aspect: base ;
        species people aspect: base ;
        species docking aspect: base ;
        graphics "text" {
				draw "day" + string(current_day) + " - " + string(current_hour) + "h" color: #white font: font("Helvetica", 25, #italic) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
				draw imageRaster size: 40 #px at: {world.shape.width * 0.95, world.shape.height * 0.95};
			}
    }
    }
}