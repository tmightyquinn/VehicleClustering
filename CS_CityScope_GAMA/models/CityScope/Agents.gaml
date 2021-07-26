/**
* Name: Vehicles
* Based on the internal empty template. 
* Author: Juan
* Tags: 
*/


model Agents

import "./clustering.gaml"


species road {
	aspect base {
		draw shape color: rgb(125, 125, 125);
	}
}


species building {
    aspect type {
		draw shape color: color_map[type];
	}
	string type; 
}

species chargingStation {
	list<bike> bikesToCharge;
	
	aspect base {
		draw circle(10) color:#blue;		
	}
	
	reflex chargeBikes {
		ask 10 first bikesToCharge {
			batteryLife <- batteryLife + step*V2IChargingRate;
		}
		save ["Question2", string(self),length(bikesToCharge)] to: "vkt_NoBikesSimultCharged.csv" type: "csv" rewrite: false;
	}
}

species tagRFID {
	int id;
	//bool checked;
	string type;
	
	list<float> pheromones;
	list<geometry> pheromonesToward;
	
	int lastUpdate;
	
	geometry towardChargingStation;
	int distanceToChargingStation;
	
	rgb color;
	reflex set_color {
		color <- #purple;
	}
	aspect base{
		draw circle(10) color:color border: #black;
	}
	
	aspect realistic{
		draw circle(1+5*max(pheromones)) color:rgb(107,171,158);
	}
}

species people control: fsm skills: [moving] {
	
	rgb color <- #yellow ;
    building living_place; //Home [lat,lon]
    building working_place; //Work [lat, lon]
    int start_work;
    int end_work;
    float morning_wait_time; //Morning wait time [s]
    float evening_wait_time; //Evening wait time [s]
    float morning_ride_duration; //Morning ride duration [s]
    float evening_ride_duration; //Evening ride duration [s]
    float morning_ride_distance; //Morning ride distance [m]
    float evening_ride_distance; //Evening ride distance [m]
    float morning_total_trip_duration; //Morning total trip duration [s]
    float evening_total_trip_duration; //Evening total trip duration [s]
    float home_departure_time; //Home departure time [s]
    float work_departure_time; //Work departure time [s]
    bool morning_trip_served;
    bool evening_trip_served;
    float time_start_ride;
    point location_start_ride;
        
    point final_destination; //Final destination for the trip
    point target; //Interim destination; the thing we are currently moving toward
    point closestIntersection;
    float waitTime;
    
    bike bikeToRide;
    
    float timeBikeRequested;
    
    aspect base {
		if state != "riding" {
			draw circle(10) color: color border: #black;
		}
    }
    
    //Should we leave for work/home? Only if it is time, and we are not already there
    bool timeToWork { return (current_date.hour = start_work) and !(self overlaps working_place); }
    bool timeToSleep { return (current_date.hour = end_work) and !(self overlaps living_place); }
    
    state idle initial: true {
    	//Watch netflix at home or something
    	enter { target <- nil; }
    	
    	transition to: requesting_bike when: timeToWork() {
    		final_destination <- any_location_in (working_place);
    	}
    	transition to: requesting_bike when: timeToSleep() {
    		final_destination <- any_location_in (living_place);
    	}
    }
	state requesting_bike {
		//Ask the system for a bike, teleport home if wait is too long
		enter {
			write "cycle: " + cycle + ", "+ string(self) + " is requesting bike";
			closestIntersection <- (tagRFID closest_to(self)).location;
		}
		
		transition to: walking when: host.waitTime(self) <= maxWaitTime {
			//Walk to closest intersection, ask a bike to meet me there
			//save ["Question1and2", 1] to: "vkt_percentageServed.csv" type: "csv" rewrite: false;
			if timeToWork() {home_departure_time <- time; morning_trip_served <- true;}
			if timeToSleep() {work_departure_time <- time; evening_trip_served <- true;}
			//bikeToRide <- host.requestBike(self);
			//bikeToRide.rider <- self;
			timeBikeRequested <- time #s;
			target <- closestIntersection;
		}
		transition to: idle {
			//teleport home
			//save ["Question1", 0] to: "vkt_percentageServed.csv" type: "csv" rewrite: false;
			if timeToWork() {home_departure_time <- time; morning_trip_served <- false; morning_wait_time <- nil; morning_ride_distance <- nil; morning_total_trip_duration <- nil;}
			if timeToSleep() {
				work_departure_time <- time; evening_trip_served <- false; evening_wait_time <- nil; evening_ride_distance <- nil; evening_total_trip_duration <- nil;
				save [string(self),living_place.location,working_place.location,home_departure_time,morning_trip_served,morning_wait_time,morning_ride_duration,morning_ride_distance,morning_total_trip_duration,work_departure_time,evening_trip_served,evening_wait_time,evening_ride_duration,evening_ride_distance,evening_total_trip_duration] to: "People.csv" type: "csv" rewrite: false;
			}
			location <- final_destination;
			write "wait too long, teleported to destination";
		}
	}
	state awaiting_bike {
		//Sit at the intersection and wait for your bike
		enter {
			write "cycle: " + cycle + ", "+ string(self) + " is awaiting bike";
			target <- nil;
		}
		
		transition to: riding when: bikeToRide.state = "dropping_off" {
			save ["Question1", time - timeBikeRequested] to: "vkt_averageWaitingTime.csv" type: "csv";
			location_start_ride <- self.location;
			time_start_ride <- time;
			if timeToWork() {morning_wait_time <- time - home_departure_time;}
			if timeToSleep() {evening_wait_time <- time - work_departure_time;}
		}
	}
	state riding {
		//do nothing, follow the bike around until it drops you off and you have to walk
		transition to: walking when: bikeToRide.state != "dropping_off" {
			if timeToWork() {morning_ride_duration <- time - time_start_ride; morning_ride_distance <- location_start_ride distance_to self.location;}
			if timeToSleep() {evening_ride_duration <- time - time_start_ride; evening_ride_distance <- location_start_ride distance_to self.location;}
			target <- final_destination;
		}
		enter {
			write "cycle: " + cycle + ", "+ string(self) + " is riding" + string(bikeToRide);
		}
		exit { bikeToRide <- nil; }
		
		//Always be at the same place as the bike
		location <- bikeToRide.location;
	}
	state walking {
		//go to your destination or nearest intersection, then wait
		transition to: idle when: location = final_destination {
			if timeToWork() {morning_total_trip_duration <- time - home_departure_time;}
			if timeToSleep() {
				evening_total_trip_duration <- time - work_departure_time;
				save [string(self),living_place.location,working_place.location,home_departure_time,morning_trip_served,morning_wait_time,morning_ride_duration,morning_ride_distance,morning_total_trip_duration,work_departure_time,evening_trip_served,evening_wait_time,evening_ride_duration,evening_ride_distance,evening_total_trip_duration] to: "People.csv" type: "csv" rewrite: false;
			}
		}
		transition to: awaiting_bike when: location = target {}
		enter {
			write "cycle: " + cycle + string(self) + "is walking";
		}
		do goto target: target on: roadNetwork;
	}
}

species bike control: fsm skills: [moving] {
	rgb color;
	map<string, rgb> color_map <- [
		"idle"::#lime,
		
		"low_battery":: #red,
		"getting_charge":: #pink,
		
		"awaiting_follower"::#magenta,
		"seeking_leader"::#magenta,
		"following"::#yellow,
		
		"picking_up"::rgb(175*1.1,175*1.6,200),
		"dropping_off"::#gamagreen
	];
	aspect realistic {
		color <- color_map[state];

		draw triangle(25) color:color border: #red rotate: heading + 90;
	}
	
	point target;
	path wanderPath;
	path myPath; //preallocation. Only used within the moveTowardTarget reflex
	point source;
	
	
	float pheromoneToDiffuse; //represents a store of pheremone (a bike can't expend more than this amount). Pheremone is restored by ___
	float pheromoneMark; //initialized to 0, never updated. Unsure what this represents
	
	float batteryLife; //Number of meters we can travel on current battery
	float distancePerCycle;
	
	int lastDistanceToChargingStation;
	
	
	bike leader;
	bike follower;
	
    
	//----------------PUBLIC FUNCTIONS-----------------
	// these are how other agents interact with this one. Not used by self
	bool availableForRide {
		return state = "idle" and !setLowBattery() and follower = nil;
	}
	//transition from idle to picking_up. Called by the global scheduler
	people rider <- nil;	
	action pickUp(people person) {
		rider <- person;
	}
	
	action waitFor(bike other) {
		follower <- other;
	}
	
	
	//----------------PRIVATE FUNCTIONS-----------------
	// no other species should touch these
	
	
	//-----CLUSTERING
	//These are our cost functions, and will be the basis of how we decide to form clusters
	float clusterCost(bike other) {
		return 10000 - chargeToGive(other);
	}
	float declusterCost(bike other) {
		//Don't decluster until you need to or you've nothing left to give
		if setLowBattery() { return 0; }
		if chargeToGive(other) <= 0 { return 0; }
		
		return 10;
	}
	//decide to follow another bike
	bool evaluateclusters {
		//create a map of every idle bike within a certain distance and their clustering costs
		//perhaps we want to cluster with following bikes in the future. Megacluster
		map<bike, float> costs <- map(((bike where (each.state="idle" and each.follower = nil)) at_distance clusterDistance) collect(each::clusterCost(each)));
		
		if empty(costs) { return false; }
		
		float minCost <- min(costs.values);
		if minCost < clusterThreshold {
			leader <- costs.keys[ costs.values index_of minCost ];
			return true;
		}
		
		return false;
	}
	
	
	//determines how much charge we could give another bike
	float chargeToGive(bike other) {
		//never go less than some minimum battery level
		//never charge leader to have more power than you
		float chargeDifference <- batteryLife - other.batteryLife;
		float chargeToSpare <- batteryLife - minSafeBattery;
		float batteryToSpare <- maxBatteryLife - other.batteryLife;
		return min(chargeDifference/2, chargeToSpare, batteryToSpare);
	}
	action chargeBike(bike other) {
		float transfer <- min( step*V2VChargingRate, chargeToGive(other));
		
		leader.batteryLife <- leader.batteryLife + transfer;
		batteryLife <- batteryLife - transfer;
	}
	
	
	
	//-----BATTERY
	float saturateBattery(float value) {
		if value < 0.0 { return 0.0;}
		if value > maxBatteryLife { return maxBatteryLife;}
		
		return value;
	}
	//Determines when to move into the low_battery state
	bool setLowBattery {
		//TODO: perhaps all these minimum values should be merged into one, to be respected here and in cluster-charging
		if batteryLife < 3*distancePerCycle { return true; } //leave 3 simulation-steps worth of movement
		if batteryLife < minSafeBattery { return true; } //we have a minSafeBattery value, might as well respect it
		return batteryLife < 10*lastDistanceToChargingStation; //safety factor
	}
	float energyCost(float distance) { //This function will let us alter the efficiency of our bikes, if we decide to look into that
		if state = "dropping_off" { return 0; } //user will pedal
		return distance;
	}
	action reduceBattery(float distance) {
		save ["Question2", energyCost(distance)] to: "vkt_energyConsumption.csv" type: "csv" rewrite: false;
		batteryLife <- batteryLife - energyCost(distance);
		batteryLife <- saturateBattery( batteryLife - energyCost(distance) );
		if follower != nil and follower.state = "following" {
			ask follower {
				do reduceBattery(distance);
			}
		}
	}
	//debug stuff
//	reflex logs when: target != nil {
//		write "cycle: " + cycle + ", power: " + batteryLife + ", distance: " + (self distance_to self.target);
//	}
	reflex deathWarning when: batteryLife = 0 {
		write "NO POWER!";
		ask host {
			do pause;
		}
	}
	
	
	//-----MOVEMENT
	float pathLength(path p) {
		if empty(p) { return 0; }
		return p.shape.perimeter; //TODO: may be accidentally doubled
	}
	list<tagRFID> lastIntersections;
	tagRFID lastTag; //last RFID tag we crossed. Useful for wander function
	
	bool canMove {
		return state != "awaiting_follower" and target != location and (target != nil or wanderPath != nil) and batteryLife > 0;
	}
	reflex moveTowardTarget when: canMove() {
		//do goto (or follow in the case of wandering, where we've prepared a probably-suboptimal route)
		if (target != nil) {
			//TODO: Think about redefining this save thing once we implement charging btw vehicles also with low charge
			if state = "low_battery" {
				save ["Question2", self.location distance_to target] to: "vkt_forCharge.csv" type: "csv" rewrite: false;
			}
			myPath <- goto(on:roadNetwork, target:target, speed:speed, return_path: true);
		} else {
			myPath <- follow(path: wanderPath, return_path: true);
		}
		//determine distance
		float distanceTraveled <- pathLength(myPath);

		do reduceBattery(distanceTraveled);
		
		if state = "idle" {
			save ["Question1", string(self), distanceTraveled] to: "vkt_rebalancing.csv" type: "csv" rewrite: false;
		}	
		
			
		if !empty(myPath) {
			//update pheromones exactly once, when we cross a new intersection
			//we could (should) have crossed multiple intersections over the last move. The location of each intersection
			//will show up in `vertices`, as they are the boundaries between new edges
			//simply casting the points to intersections is incorrect though, as we may get intersections that are close
			//to the points in question, but not actually on the path. We may also get duplicates. The filter removes both of these.
			//reverse it to make the oldest intersection first in the list
			list<tagRFID> newIntersections <- reverse( myPath.vertices where (tagRFID(each).location = each) );
//			ask newIntersections {
//				color <- #yellow;
//			}
			//update pheromones from first traveled to last traveled, ignoring those that were updated last cycle
			loop tag over: newIntersections {
				if not(tag in lastIntersections) { do updatePheromones(tag); }
			}
			
			//the future is now old man
			lastIntersections <- newIntersections;
			if (!empty(newIntersections)) { lastTag <- newIntersections[0]; }
		}
	}
	
	point chooseWanderTarget(tagRFID fromTag, tagRFID previousTag) {
		
		lastDistanceToChargingStation <- fromTag.distanceToChargingStation;
		
		list<float> edgesPheromones <- fromTag.pheromones;
		
		if(sum(edgesPheromones)=0) {
			// No pheromones,choose a random direction
			return point(fromTag.pheromonesToward[rnd(length(fromTag.pheromonesToward)-1)]);
		} else{
			// Follow strongest pheremone trail with p=exploratoryRate^2 if we just came from this direction, or p=exploratoryRate if not. Else, chose random direction
			// TODO: this random probability function can be better weighted by relative pheremone levels
			
			// Pick strongest pheromone trail (with exploratoryRate Probability if the last path has the strongest pheromone)
			float maxPheromone <- max(edgesPheromones);
			loop j from:0 to:(length(fromTag.pheromonesToward)-1) {
				if (maxPheromone = edgesPheromones[j]) and (previousTag = fromTag.pheromonesToward[j]){
					edgesPheromones[j]<- flip(exploratoryRate)? edgesPheromones[j] : 0.0;					
				}
			}
			maxPheromone <- max(edgesPheromones);	

			// Follow strongest pheromone trail (with exploratoryRate Probability in any case)
			loop j from:0 to:(length(fromTag.pheromonesToward)-1) {
				if (maxPheromone = edgesPheromones[j]){
					if flip(exploratoryRate){
						return point(fromTag.pheromonesToward[j]);
					} else {
						return point(fromTag.pheromonesToward[rnd(length(fromTag.pheromonesToward)-1)]);
					}
				}
			}
		}
		return nil; //We should not get here
	}
	
	
	//-----PHEROMONES
	action evaporatePheromones(tagRFID tag) {
		loop j from:0 to: length(tag.pheromonesToward)-1 {
			tag.pheromones[j] <- tag.pheromones[j] - (singlePheromoneMark * evaporation * step*(cycle - tag.lastUpdate));
		}
	}
	//Cap the tag's pheromones at acceptable min and max levels
	action saturatePheromones(tagRFID tag) {
		loop j from:0 to: length(tag.pheromonesToward)-1 {
			if (tag.pheromones[j]<minPheromoneLevel){
				tag.pheromones[j] <- minPheromoneLevel;
			}
			if (tag.pheromones[j]>maxPheromoneLevel){
				tag.pheromones[j] <- maxPheromoneLevel;
			}
		}
	}
	
	//Dump my pheremone at the nearest tag, pick up some from same tag via diffusion, add more pheromone to a random endpoint of the road I'm on
	action updatePheromones(tagRFID tag) {
		// ask the nearest tag to: add _all_ of my pheremone to it, update evaporation, and cap at (0, 50). If I am picking someone up, add 0 to pheremone tag (???). Set my pheremone levels to whatever the tag has diffused to me
		do evaporatePheromones(tag);
		loop j from:0 to: (length(tag.pheromonesToward)-1) {	
			tag.pheromones[j] <- tag.pheromones[j] + pheromoneToDiffuse;
			
			if(state = "picking_up" or state = "dropping_off") {
				if (tag.pheromonesToward[j]=lastTag){
					tag.pheromones[j] <- tag.pheromones[j] + pheromoneMark ;
				}
			}
		}
		
		// Saturation
		do saturatePheromones(tag);
		// Update tagRFID and pheromoneToDiffuse
		tag.lastUpdate <- cycle;
		pheromoneToDiffuse <- max(tag.pheromones)*diffusion;
	}
	
	
	/*reflex logs when: target != nil {
		write "cycle: " + cycle + ", power: " + batteryLife + ", distance: " + (self distance_to self.target);
	}*/
	reflex deathWarning when: batteryLife = 0 {
		write "NO POWER!";
		ask host {
			do pause;
		}
	}
	
	
	//-----STATE MACHINE
	state idle initial: true {
		//wander the map, follow pheromones. Same as the old searching reflex
		enter {
		    write "cycle: " + cycle + ", " + string(self) + " is wandering";
			target <- nil;
		}
		
		transition to: awaiting_follower when: follower != nil and follower.state = "seeking_leader" {}
		transition to: seeking_leader when: follower = nil and evaluateclusters() {
			//Don't form cluster if you're already a leader
			ask leader {
				do waitFor(myself);
			}
			ask host {
				do pause;
			}
		}
		transition to: low_battery when: setLowBattery() {}
		transition to: picking_up when: rider != nil {}
		
		exit {
			wanderPath <- nil;
		}
		
		
		//construct a plan, so we don't waste motion: Where will we turn from the next intersection? If we have time left in the cycle, where will we turn from there? And from the intersection after that?
		tagRFID tagWereAboutToHit <- tagRFID closest_to self; //TODO: this is incorrect. Use the road we're currently on, compare the two intersections with the one we know we just crossed
		wanderPath <- path([tagWereAboutToHit, chooseWanderTarget(tagWereAboutToHit, lastTag)]);
		loop while: pathLength(wanderPath) < distancePerCycle {
			int i <- length(wanderPath.vertices) - 1;
			tagRFID finalTag <- wanderPath.vertices[i];
			tagRFID penultimate <- wanderPath.vertices[i-1];
			wanderPath <- path( wanderPath.vertices + chooseWanderTarget(finalTag, penultimate) );
		}
		
		
	}
	
	//TODO: we need to plan ahead somehow, or we waste quite a bit of movement. Currently we move exactly 1 intersection per cycle
	state low_battery {
		//seek either a charging station or another vehicle
		enter{
			write "cycle: " + cycle + ", " + string(self) + " has low battery";
		}
		//TODO: I think this can be much more performant. Perhaps we save the target charging station in the pheromone tag so we cont have to run closest_to every cycle
		transition to: getting_charge when: self.location = (chargingStation closest_to self).location {}
		
		ask tagRFID closest_to(self) {
			// Update direction and distance from closest Docking station
			myself.target <- point(self.towardChargingStation);
			myself.lastDistanceToChargingStation <- self.distanceToChargingStation;		
		}
		source <- location;
	}
	
	state getting_charge {
		//sit at a charging station until charged
		enter {
			write "cycle: " + cycle + ", " + string(self) + " is getting charged in station";
			target <- nil;
			ask chargingStation closest_to(self) {
				bikesToCharge <- bikesToCharge + myself;
			}
		}
		transition to: idle when: batteryLife >= maxBatteryLife {}
		exit {
			//TODO: If possible, refine this so that bikes are not overcharged and we use that time.
			batteryLife <- maxBatteryLife;
			ask chargingStation closest_to(self) {
				bikesToCharge <- bikesToCharge - myself;
			}
		}
	}
	
	state awaiting_follower {
		//sit at an intersection until a follower joins the cluster
		enter {
			write "cycle: " + cycle + ", " + string(self) + " is awaiting follower";
		}
		transition to: idle when: follower.state = "following" {}
	}
	state seeking_leader {
		//catch up to the leader
		//(when two bikes form a cluster, one will await_follower, the other will seek_leader)
		transition to: following when: (self distance_to leader) <= followDistance {}
		enter {
			write "cycle: " + cycle + ", " + string(self) + " is seeking " + leader;
		}
		exit {
			target <- nil;
		}
		
		//best to repeat this, in case the leader moves after we save its location
		target <- leader.location;
	}
	state following {
		//transfer charge to host, follow them around the map
		location <- leader.location;
		do chargeBike(leader);
		//leader will update our charge level as we move along (see reduceBattery)
		//TODO: While getting charged, if there is a request for picking up, charging vehicle must leave
		enter {
			write "cycle: " + cycle + ", " + string(self) + " is following " + leader;
		}
		transition to: idle when: declusterCost(leader) < declusterThreshold {
			ask leader {
				follower <- nil;
			}
			leader <- nil;
		}
	}
	
	state picking_up {
		//go to rider's location, pick them up
		enter {
			write "cycle: " + cycle + ", " + string(self) + " is picking up "+string(rider);
			target <- rider.closestIntersection; //Go to the rider's closest intersection
			save ["Question1", string(self), self.location distance_to target] to: "vkt_pickingUp.csv" type: "csv" rewrite: false;
		}
		
		transition to: dropping_off when: location=target and rider.location=target{}
	}
	
	state dropping_off {
		//go to rider's destination, drop them off
		enter {
			write "cycle: " + cycle + ", " + string(self) + " is dropping off "+string(rider);
			target <- (tagRFID closest_to rider.final_destination).location;
		}
		
		transition to: idle when: location=target {
			rider <- nil;
		}
	}
}
