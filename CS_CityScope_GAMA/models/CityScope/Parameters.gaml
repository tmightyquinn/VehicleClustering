/**
* Name: Parameters
* Based on the internal empty template. 
* Author: Juan
* Tags: 
*/


model Parameters

import "./clustering.gaml"
/* Insert your model definition here */
global{
	//-------------------------------------------------------------My Parameters----------------------------------------------------------------------------------
	//Number of Bikes to generate. Juan: Change this so nb is generated according to real GIS Data.
	int bikeNum <- 1 min: 1 max: 1000 parameter: "Nb Vehicle:" category: "Initial";
	//Max battery life of bikes.
	int maxBatteryLife <- 200; // 2 h for PEV considering each cycle as 10 seconds in the real world
	//Max speed distance of Bikes
	float maxSpeedDist <- 2.5; // about 5.5  m/s for PEV (it can be changed accordingly to different robot specification)
	//Number of docking stations
	int dockingNum <- 2;
	//Number of people
	int nb_people <- 1;
			
}	