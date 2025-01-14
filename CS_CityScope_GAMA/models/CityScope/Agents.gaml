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
		ask dockingStationCapacity first bikesToCharge {
			batteryLife <- batteryLife + step*V2IChargingRate;
		}
	}
}

species tagRFID {
	int id;
	
	map<tagRFID,float> pheromoneMap;
	
	int lastUpdate; //Cycle
	
	chargingStation nearestChargingStation;
	int distanceToChargingStation;
	
	//easy access to neighbors
	list<tagRFID> neighbors { return pheromoneMap.keys;	}
	
	
	rgb color;
	reflex set_color {
		color <- #purple;
	}
	aspect base {
		draw circle(10) color:color border: #black;
	}
	
	aspect realistic {
		draw circle(1+5*max(pheromoneMap)) color:rgb(107,171,158);
	}
}

species people control: fsm skills: [moving] {
	
	rgb color <- #yellow ;
    building living_place; //Home [lat,lon]
    building working_place; //Work [lat, lon]
    int start_work;
    int end_work;
    
    peopleLogger logger;
    peopleLogger_trip tripLogger;
    
    
    
        
    point final_destination; //Final destination for the trip
    point target; //Interim destination; the thing we are currently moving toward
    point closestIntersection;
    float waitTime;
    
    bike bikeToRide;
    
    
    aspect base {
		if state != "riding" {
			draw circle(10) color: color border: #black;
		}
    }
    
    //----------------PUBLIC FUNCTIONS-----------------
	// these are how other agents interact with this one. Not used by self
    action ride(bike b) {
    	bikeToRide <- b;
    }	
	
	
    //Should we leave for work/home? Only if it is time, and we are not already there
    bool timeToWork { return (current_date.hour = start_work) and !(self overlaps working_place); }
    bool timeToSleep { return (current_date.hour = end_work) and !(self overlaps living_place); }
    
    state idle initial: true {
    	//Watch netflix at home or something
    	enter {
    		ask logger { do logEnterState; }
    		target <- nil;
    	}
    	transition to: requesting_bike when: timeToWork() {
    		final_destination <- any_location_in (working_place);
    	}
    	transition to: requesting_bike when: timeToSleep() {
    		final_destination <- any_location_in (living_place);
    	}
    	exit {
			ask logger { do logExitState; }
		}
    }
	state requesting_bike {
		//Ask the system for a bike, teleport home if wait is too long
		enter {
			ask logger { do logEnterState; }
			closestIntersection <- (tagRFID closest_to(self)).location;
		}
		
		transition to: walking when: host.requestBike(self) {
			target <- closestIntersection;
		}
		transition to: idle {
			//teleport home
			ask logger { do logEvent( "Teleported Home, wait too long" ); }
			location <- final_destination;
		}
		exit {
			ask logger { do logExitState; }
		}
	}
	state awaiting_bike {
		//Sit at the intersection and wait for your bike
		enter {
			ask logger { do logEnterState( "awaiting " + string(myself.bikeToRide) ); }
			target <- nil;
		}
		transition to: riding when: bikeToRide.state = "dropping_off" {}
		exit {
			ask logger { do logExitState; }
		}
	}
	state riding {
		//do nothing, follow the bike around until it drops you off and you have to walk
		enter {
			ask logger { do logEnterState( "riding " + string(myself.bikeToRide) ); }
		}
		transition to: walking when: bikeToRide.state != "dropping_off" {
			target <- final_destination;
		}
		exit {
			ask logger { do logExitState; }
			bikeToRide <- nil;
		}
		
		//Always be at the same place as the bike
		location <- bikeToRide.location;
	}
	state walking {
		//go to your destination or nearest intersection, then wait
		enter {
			ask logger { do logEnterState; }
		}
		transition to: idle when: location = final_destination {}
		transition to: awaiting_bike when: location = target {}
		exit {
			ask logger { do logExitState; }
		}
		
		
		do goto target: target on: roadNetwork;
	}
}

species bike control: fsm skills: [moving] {
	//----------------Display-----------------
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
	
	
	bikeLogger_roadsTraveled travelLogger;
	bikeLogger_chargeEvents chargeLogger;
	bikeLogger_event eventLogger;
	
	
	    
	/* ========================================== PUBLIC FUNCTIONS ========================================= */
	// these are how other agents interact with this one. Not used by self
	bike leader;
	bike follower;
	people rider;
	
	
	bool availableForRide {
		return (state = "idle" or state = "following") and !setLowBattery();
	}
	list<string> platoonStates <- ["idle","picking_up"];
	bool availableForPlatoon {
		// Bike must either be idle, or awaiting another follower, have no followers
		//TODO: may need more filters. Must exclude dropping_off, for example
		return (state in platoonStates) and follower = nil and !setLowBattery();
	}
	
	//transition from idle to picking_up. Called by the global scheduler
	action pickUp(people person) {
		rider <- person;
	}
	
	action waitFor(bike other) {
		follower <- other;
	}
	
	
	/* ========================================== PRIVATE FUNCTIONS ========================================= */
	// no other species should touch these
	
	
	//----------------Clustering-----------------
	//These are our cost functions, and will be the basis of how we decide to form clusters
	float clusterCost(bike other) {
		return 10000 - chargeToGive(other);
	}
	float declusterCost(bike other) {
		//Don't decluster until you need to or you've nothing left to give
		if other.state = "dropping_off" { return -10; }
		if setLowBattery() { return -10; }
		if chargeToGive(other) <= 0 { return -10; }
		
		return 10;
	}
	
	//decide to follow another bike
	bool evaluateclusters {
		//create a map of every available bike within a certain distance and their clustering costs
		//perhaps we want to cluster with following bikes in the future. Megacluster
		map<bike, float> costs <- map(((bike where (each.availableForPlatoon())) at_distance clusterDistance) collect(each::clusterCost(each)));
		
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
	
	
	
	//----------------BATTERY-----------------
	
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
		batteryLife <- batteryLife - energyCost(distance);
    
		if follower != nil and follower.state = "following" {
			ask follower {
				do reduceBattery(distance);
			}
		}
	}
	
	
	//----------------MOVEMENT-----------------
	point target;
	
	//this should be affected by how many bikes there are in a cluster
		//[Q] Nah. Instead, see the energy_cost function
	float batteryLife min: 0.0 max: maxBatteryLife; //Number of meters we can travel on current battery
	float distancePerCycle;
	
	int lastDistanceToChargingStation;
	path travelledPath; //preallocation. Only used within the moveTowardTarget reflex
	
	float pathLength(path p) {
		if empty(p) or p.shape = nil { return 0; }
		return p.shape.perimeter; //TODO: may be accidentally doubled
	}
	list<tagRFID> lastIntersections;
	
	tagRFID lastTag; //last RFID tag we passed. Useful for wander function
	tagRFID nextTag; //tag we ended on OR the next tag we will reach
	
	bool canMove {
		return state != "awaiting_follower" and target != location and (target != nil or state="idle") and batteryLife > 0;
	}
	
	
	path moveTowardTarget {
		return goto(on:roadNetwork, target:target, return_path: true);
	}
	path wander {
		//construct a plan, so we don't waste motion: Where will we turn from the next intersection? If we have time left in the cycle, where will we turn from there? And from the intersection after that?
		list<point> plan <- [location, nextTag.location];
		
		loop while: pathLength(path(plan)) < distancePerCycle {
			tagRFID newTag <- chooseWanderTarget(nextTag, lastTag);
			
			lastTag <- nextTag;
			nextTag <- newTag;
			plan <- plan + newTag.location;
		}
		
		//using follow can result in some drift when the road is curved (follow will use straight lines). I have not found a solution to this
		return follow(path:path(plan), return_path: true);
	}
	
	reflex move when: canMove() {
		//do goto (or follow in the case of wandering, where we've prepared a probably-suboptimal route)
		travelledPath <- (state = "idle") ? wander() : moveTowardTarget();
		float distanceTraveled <- pathLength(travelledPath);
		
		do reduceBattery(distanceTraveled);
			
		if !empty(travelledPath) {
			/* update pheromones exactly once, when we cross a new intersection
			 * we could (should) have crossed multiple intersections over the last move. The location of each intersection
			 * will show up in `vertices`, as they are the boundaries between new edges
			 * simply casting the points to intersections is incorrect though, as we may get intersections that are close to
			 * the points in question, but not actually on the path. We may also get duplicates. The filter removes both of these.
			 */
			
			//oldest intersection is first in the list
			
			list<tagRFID> newIntersections <- travelledPath.vertices where (tagRFID(each).location = each);
			int num <- length(newIntersections);
			
			
			//update pheromones from first traveled to last traveled, ignoring those that were updated last cycle
			
			
			//update lastTag, nextTag. If we landed on nextTag, remove it from the list
			if (!empty(newIntersections)) {
				tagRFID mostRecentTag <- last(newIntersections);
				tagRFID penultimateTag <- num = 1 ? last(lastIntersections) : newIntersections[num - 2];
				
				if location = mostRecentTag.location {
					//we have stopped at an intersection
					nextTag <- mostRecentTag;
					lastTag <- penultimateTag;
					newIntersections <- copy_between( newIntersections, 0, num-1); 
					//pop the last intersection off the end, we'll process it next iteration
					//(We should always read the data _before_ we overwrite it. We have not yet read this tag, so we push writing over it to the future)
					//Also prevents overlap between new and last intersection lists
				} else {
					//we have stopped in the middle of a road
					lastTag <- mostRecentTag;
					
					//current edge will have two points on it, one is lastTag, the otherr is nextTag
					nextTag <- tagRFID( (current_edge.points where (each != lastTag.location))[0] );
				}
			}
			
			//remember read pheromones without looking at what we have added to them
			do rememberPheromones(newIntersections);
			//add pheromones
			loop tag over: newIntersections {
				do depositPheromones(tag);
			}
			
			//the future is now old man (overwrite old saved data)
			lastIntersections <- newIntersections;
			
			ask travelLogger { do logRoads(distanceTraveled, num); }
		}
		
		
		
		lastDistanceToChargingStation <- lastTag.distanceToChargingStation;
	}
	
	//Low-pass filter average!
	float readPheromones <- 2*chargingPheromoneThreshold; //init above the threshold so we don't imediately go to charge
	float alpha <- 0.2; //tune this so our average updates at desired speed. may need a factor of `step`
	action rememberPheromones(list<tagRFID> tags) {
		loop tag over: tags {
			readPheromones <- (1-alpha)*readPheromones + alpha*mean(tag.pheromoneMap);
		}
	}
	
	
	tagRFID chooseWanderTarget(tagRFID fromTag, tagRFID previousTag) {
		do updatePheromones(fromTag);
		
		//c.f. rnd_choice alters probability based on values, may be useful
		map<tagRFID,float> pmap <- fromTag.pheromoneMap;

		//only one road out of here, take it
		if length(pmap) = 1 { return pmap.keys[0]; }

		//no pheromones to read, choose randomly.
		if sum(pmap.values) <= 0 { return one_of( pmap.keys ); }

		
		//if the strongest pheromone is behind us, keep pheromone level with p=exploratory rate
		if pmap[previousTag] = max(pmap) and not flip(exploratoryRate) {
			pmap[previousTag] <- 0.0; //alters local copy only :)
		}
		
		//head toward (possibly new) strongest pheromone, or choose randomly
		if flip(exploratoryRate) {
			return pmap index_of max(pmap);
		} else {
			return one_of( pmap.keys );
		}
	}
	
	
	//----------------PHEROMONES-----------------
	float pheromoneToDiffuse; //represents a store of pheremone (a bike can't expend more than this amount). Pheremone is restored by ___
	float pheromoneMark; //initialized to 0, never updated. Unsure what this represents
	
	
	action updatePheromones(tagRFID tag) {
	
		loop k over: tag.pheromoneMap.keys {
			//evaporation
			tag.pheromoneMap[k] <- tag.pheromoneMap[k] - (singlePheromoneMark * evaporation * step*(cycle - tag.lastUpdate));

			//saturation
			if (tag.pheromoneMap[k]<minPheromoneLevel){
				tag.pheromoneMap[k] <- minPheromoneLevel;
			}
			if (tag.pheromoneMap[k]>maxPheromoneLevel){
				tag.pheromoneMap[k] <- maxPheromoneLevel;
			}
		}
		
		tag.lastUpdate <- cycle;
	}
	
	action depositPheromones(tagRFID tag) {
		
		// add _all_ of my pheremone to nearest tag. If I am picking someone up, add 0 to pheremone tag (???). Set my pheremone levels to whatever the tag has diffused to me
		bool depositPheromone <- state = "picking_up" or state = "dropping_off";
		loop k over: tag.pheromoneMap.keys {
			tag.pheromoneMap[k] <- tag.pheromoneMap[k] + pheromoneToDiffuse; //Why do we add pheromone to all of them?
			if k = lastTag and depositPheromone {
				tag.pheromoneMap[k] <- tag.pheromoneMap[k] + pheromoneMark; //This line does nothing and I don't understand why
			}
		}
		
		// Saturation, Evaporation
		do updatePheromones(tag);
		
		pheromoneToDiffuse <- max(tag.pheromoneMap)*diffusion;
	}
	
	
	/* ========================================== STATE MACHINE ========================================= */
	state idle initial: true {
		//wander the map, follow pheromones. Same as the old searching reflex
		enter {
			target <- nil;
			ask eventLogger { do logEnterState; }
		}
		transition to: awaiting_follower when: follower != nil and follower.state = "seeking_leader" {}
		transition to: seeking_leader when: follower = nil and evaluateclusters() {
			//Don't form cluster if you're already a leader
			ask leader {
				do waitFor(myself);
			}
		}
		transition to: low_battery when: setLowBattery() or readPheromones < chargingPheromoneThreshold {}
		transition to: picking_up when: rider != nil {}
		exit {
			ask eventLogger { do logExitState; }
		}
		
		//Wandering is handled by the move reflex
	}
	
	state low_battery {
		//seek either a charging station or another vehicle
		enter{
			ask eventLogger { do logEnterState(myself.state); }
			//Technically, the bike would pause at each intersection to read the direction to the nearest charging station
			//This wastes a lot of time in simulation, so we are cheating
			//The path the bike follows is identical.
			target <- lastTag.nearestChargingStation.location;
		}
		transition to: getting_charge when: self.location = target {}
		exit {
			ask eventLogger { do logExitState; }
		}
		
		//Movement is handled by the move reflex
	}
	
	state getting_charge {
		//sit at a charging station until charged
		enter {
			ask eventLogger { do logEnterState("Charging at " + (chargingStation closest_to myself)); }
			
			target <- nil;
			
			ask chargingStation closest_to(self) {
				bikesToCharge <- bikesToCharge + myself;
			}
		}
		transition to: idle when: batteryLife >= maxBatteryLife {}
		exit {
			ask eventLogger { do logExitState("Charged at " + (chargingStation closest_to myself)); }
			
			//TODO: If possible, refine this so that bikes are not overcharged and we use that time.
			ask chargingStation closest_to(self) {
				bikesToCharge <- bikesToCharge - myself;
			}
		}
		
		//charging station will reflexively add power to this bike
	}
	
	state awaiting_follower {
		//sit at an intersection until a follower joins the cluster
		enter {
			ask eventLogger { do logEnterState("Awaiting Follower " + myself.follower); }
		}
		transition to: idle when: follower.state = "following" {}
		exit {
			ask eventLogger { do logExitState("Awaited Follower " + myself.follower); }
		}
		
		//Move reflex does not fire when in this state
	}
	state seeking_leader {
		//catch up to the leader
		//(when two bikes form a cluster, one will await_follower, the other will seek_leader)
		enter {
			ask eventLogger { do logEnterState("Seeking Leader " + myself.leader); }
		}
		transition to: following when: (self distance_to leader) <= followDistance {}
		exit {
			ask eventLogger { do logExitState("Sought Leader " + myself.leader); }
			target <- nil;
		}
		
		//best to repeat this, in case the leader moves after we save its location
		target <- leader.location;
	}
	state following {
		enter {
			ask eventLogger { do logEnterState("Following " + myself.leader); }
		}
		transition to: idle when: declusterCost(leader) < declusterThreshold {}
		transition to: picking_up when: rider != nil {}
		exit {
			ask eventLogger { do logExitState("Followed " + myself.leader); }
			ask leader {
				follower <- nil;
			}
			leader <- nil;
		}
		
		
		//transfer charge to host, follow them around the map
		location <- leader.location;
		do chargeBike(leader);
		//leader will update our charge level as we move along (see reduceBattery)
		//TODO: While getting charged, if there is a request for picking up, charging vehicle must leave
	}
	
	//BIKE - PEOPLE
	state picking_up {
		//go to rider's location, pick them up
		enter {
			ask eventLogger { do logEnterState("Picking up " + myself.rider); }
			target <- rider.closestIntersection; //Go to the rider's closest intersection
		}
		
		transition to: dropping_off when: location=target and rider.location=target {}
		exit{
			ask eventLogger { do logExitState("Picked up " + myself.rider); }
		}
	}
	
	state dropping_off {
		//go to rider's destination, drop them off
		enter {
			ask eventLogger { do logEnterState("Dropping Off " + myself.rider); }
			target <- (tagRFID closest_to rider.final_destination).location;
		}
		
		transition to: idle when: location=target {
			rider <- nil;
		}
		exit {
			ask eventLogger { do logExitState("Dropped Off " + myself.rider); }
		}
	}
}
