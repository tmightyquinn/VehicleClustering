/**
* Name: Parameters
* Based on the internal empty template. 
* Author: Juan
* Tags: 
*/


model Parameters

import "./clustering.gaml"
/* Insert your model definition here */
global {
	//----------------------Simulation Parameters------------------------
	//Simulation time step
	float step <- 45 #sec;
	
	//----------------------Logging Parameters------------------------
	int loggingLevel <- 10		min: 0 max: 10 parameter: "Logging Level" category: "Logs";
	int printLevel <- 1			min: 0 max: 10 parameter: "Printing Level" category: "Logs";
	bool bikeLogs <- true		parameter: "Bike Logs" category: "Logs";
	string bikeFile <- "bikes"	parameter: "Bike Logfile" category: "Logs";
	bool peopleLogs <- true		parameter: "People Logs" category: "Logs";
	string peopleFile <- "people"	parameter: "Person Logfile" category: "Logs";
	bool stationLogs <- true		parameter: "Charging Station Logs" category: "Logs";
	string stationFile <- "stations"	parameter: "Charging Station Logfile" category: "Logs";
	
	
	//----------------------Pheromone Parameters------------------------
    float singlePheromoneMark <- 0.5;
	float evaporation <- 0.005; //unsure of this value - changed evaporation to be proportional to time instead of cycles
	float exploratoryRate <- 0.8;
	float diffusion <- (1-exploratoryRate) * 0.5; 
	float maxPheromoneLevel <- 50*singlePheromoneMark;
	float minPheromoneLevel <- 0.0;
	
	//----------------------Bike Parameters------------------------
	//Number of Bikes to generate. Juan: Change this so nb is generated according to real GIS Data.
	int numBikes <- 5 				min: 0 max: 500 parameter: "Num Bikes:" category: "Initial";
	//Max battery life of bikes - Maximum number of meters with the battery
	float maxBatteryLife <- 100000 #m	min: 10000#m max: 300000#m parameter: "Battery Capacity (m):" category: "Bike";
	//speed of bikes - about 5.5  m/s for PEV (it can be changed accordingly to different robot specification)
	float BikeSpeed <- 2.5 #m/#s min: 1 #m/#s max: 15#m/#s parameter: "Bike Top Speed (m/s):" category:  "Bike";
	
	float clusterDistance <- 100#m;
	float clusterThreshold <- 0.5;
	float declusterThreshold <- 0.5;
	float followDistance <- 5#m;
	float V2VChargingRate <- 20 #m/#s;
	
	float chargingPheromoneThreshold <- 0*singlePheromoneMark; //Disables charge-seeking when low pheromone
	
	
	float minSafeBattery <- 25000 #m;
	
	float rideDistance <- 200 #m;
	
	//----------------------Docking Parameters------------------------
	//Number of docking stations
	int numDockingStations <- 2 	min: 1 max: 10 parameter: "Num Docking Stations:" category: "Initial";
	float V2IChargingRate <- 2000 #m/#s min: 1 #m/#s max: 2000 #m/#s parameter: "V2I Charging Rate (m/s):" category: "Charging";
	int dockingStationCapacity <- 10;
	
	//----------------------People Parameters------------------------
	int numPeople <- 5 				min: 0 max: 1000 parameter: "Num People:" category: "Initial";
	float maxWaitTime <- 20#mn		min: 3#mn max: 60#mn parameter: "Max Wait Time:" category: "People";
    int workStartMin <- 6			min: 4 max: 12 parameter: "Min Work Start Time:" category: "People";
    int workStartMax <- 8			min: 4 max: 12 parameter: "Max Work Start Time:" category: "People";
    int workEndMin <- 16			min: 14 max: 24 parameter: "Min Work End Time:" category: "People";
    int workEndMax <- 20			min: 14 max: 24 parameter: "Max Work End Time:" category: "People";
    float minSpeedPeople <- 1.0 #km/#h	min: 0.5#km/#h max: 10#km/#h parameter: "People Min Speed (m/s):" category: "People";
    float maxSpeedPeople <- 5.0 #km/#h	min: 0.5#km/#h max: 10#km/#h parameter: "People Max Speed (m/s):" category: "People";
    
    
	
	
	//GIS FILES To Upload
	//Case 1 - Urban Swarms Map
 	string cityScopeCity<-"UrbanSwarm";
	string cityGISFolder <- "./../../includes/City/"+cityScopeCity;
	file bound_shapefile <- file(cityGISFolder + "/Bounds.shp")			parameter: "Bounds Shapefile:" category: "GIS";
	file buildings_shapefile <- file(cityGISFolder + "/Buildings.shp")	parameter: "Building Shapefile:" category: "GIS";
	file roads_shapefile <- file(cityGISFolder + "/Roads.shp")			parameter: "Road Shapefile:" category: "GIS";
	map<string, rgb> color_map <- ["R"::#white, "O"::#gray, "Other"::#black];	
	//Case 2 - Cambridge Map
	/*
	string cityScopeCity<-"clustering";
	string cityGISFolder <- "./../../includes/City/"+cityScopeCity;
	file bound_shapefile <- file(cityGISFolder + "/BOUNDARY_CityBoundary.shp");
	file buildings_shapefile <- file(cityGISFolder + "/CDD_LandUse.shp");
	file roads_shapefile <- file(cityGISFolder + "/TRANS_CenterLines.shp");
	file dockingStations <- file(cityGISFolder + "/dockingStations.shp");
	file dockingStations <- file("./../../includes/City/clustering" + "/dockingStations.shp");
	map<string, rgb> color_map <- ["Residential"::#white, "Office"::#gray, "Other"::#black];
	 */
	//Image File
	file imageRaster <- file('./../../images/gama_black.png');
			
}	