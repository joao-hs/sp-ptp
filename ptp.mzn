% Imports

include "cumulative.mzn";

% Parameters

bool : sameVehicleBackward;
int : maxWaitTime;

int : noPlaces;
enum PlaceCategory = {MedicalCenter, VehicleDepot, PatientLocation};
array [1..noPlaces] of PlaceCategory : placeCategory;

int : noVehicles;
int : noShifts;
int : noCategories;
enum ShiftPos = {ShiftStart, ShiftEnd};
array [1..noVehicles, 1..noCategories] of int : vehicleCanTake;
array [1..noVehicles] of int : vehicleStart;
array [1..noVehicles] of int : vehicleEnd;
array [1..noVehicles] of int : vehicleCapacity;
array [1..noVehicles, 1..noShifts, ShiftPos] of int : vehicleAvailability;

int : noRequests;
array [1..noRequests] of int : requestStart; % -1 if the patient is already at the medical center
array [1..noRequests] of int : requestDestination;
array [1..noRequests] of int : requestReturn; % -1 if there's no need to return
array [1..noRequests] of int : requestLoad;
array [1..noRequests] of int : requestServiceStartTime;
array [1..noRequests] of int : requestServiceDuration;
array [1..noRequests] of int : requestCategory;
array [1..noRequests] of int : requestBoardingDuration;

array [1..noPlaces, 1..noPlaces] of int : distMatrix;


% Check if parameters are as expected

output ["sameVehicleBackward = ", show(sameVehicleBackward), "\n"];
output ["maxWaitTime = ", show(maxWaitTime), "\n"];

output ["noPlaces = ", show(noPlaces), "\n"];
output ["placeCategory = ", show(placeCategory), "\n"];

output ["noVehicles = ", show(noVehicles), "\n"];
output ["noShifts = ", show(noShifts), "\n"];
output ["vehicleCanTake = ", show(vehicleCanTake), "\n"];
output ["vehicleStart = ", show(vehicleStart), "\n"];
output ["vehicleEnd = ", show(vehicleEnd), "\n"];
output ["vehicleCapacity = ", show(vehicleCapacity), "\n"];
output ["vehicleAvailability = ", show(vehicleAvailability), "\n"];

output ["noRequests = ", show(noRequests), "\n"];
output ["requestStart = ", show(requestStart), "\n"];
output ["requestDestination = ", show(requestDestination), "\n"];
output ["requestReturn = ", show(requestReturn), "\n"];
output ["requestLoad = ", show(requestLoad), "\n"];
output ["requestServiceStartTime = ", show(requestServiceStartTime), "\n"];
output ["requestServiceDuration = ", show(requestServiceDuration), "\n"];
output ["requestCategory = ", show(requestCategory), "\n"];
output ["requestBoardingDuration = ", show(requestBoardingDuration), "\n"];

output ["distMatrix = ", show(distMatrix), "\n"];


% Support for decision variables

int : DAY_IN_MINUTES = 1440; % 24 hours in minutes
enum ActivityType = {Forward, Backward};


% Decision Variables

% Testing variables
array [1..2*noRequests] of var 0..DAY_IN_MINUTES : activityStart2;
array [1..2*noRequests] of var 0..DAY_IN_MINUTES : activityDuration2;
array [1..2*noRequests] of var 0..DAY_IN_MINUTES : activityEnd2; % start + duration, may be irrelevant
array [1..2*noRequests] of var bool : activityExecutionStatus2;
array [1..2*noRequests] of var 0..noVehicles : activityVehicle2;

array [1..noRequests, ActivityType] of var 0..DAY_IN_MINUTES : activityStart;
array [1..noRequests, ActivityType] of var 0..DAY_IN_MINUTES : activityDuration;
array [1..noRequests, ActivityType] of var 0..DAY_IN_MINUTES : activityEnd; % start + duration, may be irrelevant
array [1..noRequests, ActivityType] of var bool : activityExecutionStatus;
array [1..noRequests, ActivityType] of var 0..noVehicles : activityVehicle;

var 0..noRequests : grantedRequests = count(i in 1..noRequests)(activityExecutionStatus[i, Forward] /\ activityExecutionStatus[i, Backward]);

solve maximize grantedRequests;

output ["grantedRequests = ", show(grantedRequests), "\n"];
output ["activityStart = ", show(activityStart), "\n"];
output ["activityDuration = ", show(activityDuration), "\n"];
output ["activityEnd = ", show(activityEnd), "\n"];
output ["activityExecutionStatus = ", show(activityExecutionStatus), "\n"];
output ["activityVehicle = ", show(activityVehicle), "\n"];

% Specific domains as constraints
% Might be optimizable
constraint forall (i in 1..noRequests) 
    (
        (activityStart[i, Forward] >= 0 /\ activityStart[i, Forward] <= requestServiceStartTime[i]) /\
        (activityEnd[i, Forward] >= 0 /\ activityEnd[i, Forward] <= requestServiceStartTime[i]) /\ 
        (activityDuration[i, Forward] = activityEnd[i, Forward] - activityStart[i, Forward]) %/\
        %(activityVehicle[i, Forward] in [vehicleCanTake[v, requestCategory[i]] | v in 1..noVehicles]) not ready yet 
        
        /\
        
        (activityStart[i, Backward] >= requestServiceStartTime[i]+requestServiceDuration[i] /\ activityStart[i, Backward] <= DAY_IN_MINUTES) /\
        (activityEnd[i, Backward] >= requestServiceStartTime[i]+requestServiceDuration[i] /\ activityEnd[i, Backward] <= DAY_IN_MINUTES) /\
        (activityDuration[i, Backward] = activityEnd[i, Backward] - activityStart[i, Backward]) %/\
        %(activityVehicle[i, Backward] in [vehicleCanTake[v, requestCategory[i]] | v in 1..noVehicles]) not ready yet
    );

% Constraints

% Binding Requests to Activities
% Maybe  this one isn't necessary since you did it above

% constraint forall(i in 1..noRequests) (activityExecutionStatus[i, Forward] /\ activityExecutionStatus[i, Backward]);

constraint forall(i in 1..2*noRequests where (i mod 2) != 0) (activityExecutionStatus2[i] /\ activityExecutionStatus2[i + 1]);

% Forward and Backward Selection

% constraint forall(i in 1..noRequests) (activityExecutionStatus[i, Forward] = activityExecutionStatus[i, Backward]);

constraint forall(i in 1..2*noRequests where (i mod 2) != 0) (activityExecutionStatus2[i] /\ activityExecutionStatus2[i + 1]);

% Inter-Activity Time Travel Consistency
% might something in between each constraint or to create 4 different ones. And not sure what srv is supposed to be I think it's what I wrote maybe it's requestBoardingDuration

% constraint forall(i, j in 1..noRequests, t in ActivityType where i != j /\ activityVehicle[i, t] = activityVehicle[j, t] ) (
%     (activityStart[j, t] - activityStart[i, t] >= distMatrix[requestStart[i], requestStart[j]] + requestBoardingDuration[i]
%         \/ activityStart[i, t] - activityStart[j, t] >= distMatrix[requestStart[j], requestStart[i]] + requestBoardingDuration[j])
    
%     /\ (activityStart[j, t] - activityEnd[i, t] >= distMatrix[requestStart[i], requestDestination[j]]                                                           
%         \/ activityEnd[i, t] - activityStart[j, t] >= distMatrix[requestDestination[j], requestStart[i]] + requestBoardingDuration[j] + requestBoardingDuration[i])
    
%     /\ (activityEnd[j, t] - activityStart[i, t] >= distMatrix[requestDestination[i], requestStart[j]] + requestBoardingDuration[i] + requestBoardingDuration[j]
%         \/ activityStart[i, t] - activityEnd[j, t] >= distMatrix[requestStart[j], requestDestination[i]]) 
    
%     /\ (activityEnd[j, t] - activityEnd[i, t] >= distMatrix[requestDestination[i], requestDestination[j]] + requestBoardingDuration[j]
%         \/ activityEnd[i, t] - activityEnd[j, t] >= distMatrix[requestDestination[j], requestDestination[i]] + requestBoardingDuration[i])
% );

constraint forall(i, j in 1..2*noRequests where i != j /\ i != j+1 /\ j != i+1 /\ activityVehicle2[i] = activityVehicle2[j] ) (
    (activityStart2[j] - activityStart2[i] >= distMatrix[requestStart[i], requestStart[j]] + requestBoardingDuration[i]
        \/ activityStart2[i] - activityStart2[j] >= distMatrix[requestStart[j], requestStart[i]] + requestBoardingDuration[j])
    
    /\ (activityStart2[j] - activityEnd2[i] >= distMatrix[requestStart[i], requestDestination[j]]                                                           
        \/ activityEnd2[i] - activityStart2[j] >= distMatrix[requestDestination[j], requestStart[i]] + requestBoardingDuration[j] + requestBoardingDuration[i])
    
    /\ (activityEnd2[j] - activityStart2[i] >= distMatrix[requestDestination[i], requestStart[j]] + requestBoardingDuration[i] + requestBoardingDuration[j]
        \/ activityStart2[i] - activityEnd2[j] >= distMatrix[requestStart[j], requestDestination[i]]) 
    
    /\ (activityEnd2[j] - activityEnd2[i] >= distMatrix[requestDestination[i], requestDestination[j]] + requestBoardingDuration[j]
        \/ activityEnd2[i] - activityEnd2[j] >= distMatrix[requestDestination[j], requestDestination[i]] + requestBoardingDuration[i])
);

% Intra-Activity Time Travel Consistency

% constraint forall(i in 1..noRequests) (activityDuration[i, Forward] >= distMatrix[requestStart[i], requestDestination[i]] /\ activityDuration[i, Backward] >= distMatrix[requestDestination[i], requestReturn[i]]);

constraint forall(i in 1..2*noRequests where (i mod 2) != 0) (activityDuration2[i] >= distMatrix[requestStart[i], requestDestination[i]] /\ activityDuration2[i+1] >= distMatrix[requestDestination[i], requestReturn[i]]);

% Maximum Travel Time - Don't think this is a constraint for our project

% constraint forall(i in 1..noRequests) (activityDuration[i] <= maxWaitTime)

% Cumulative Resource

constraint forall(j in 1..noVehicles, i in 1..2*noRequests where activityVehicle2[i] = j) (cumulative( activityStart2, activityDuration2, requestLoad, vehicleCapacity[j]));

% N-2. Ensure that the activity start and end times are consistent with the vehicle's availability

% constraint forall (i in 1..noRequests where requestStart[i] != -1)
%     (activityStart[i, fb] >= 
%         vehicleAvailability[activityVehicle[i, fb], any, ShiftStart] + 
%         requestBoardingDuration[i] + 
%         distMatrix[requestStart[i], vehicleStart[activityVehicle[i, fb]]] | fb in (Forward, Backward));

% constraint forall (i in 1..noRequests where requestReturn[i] != -1)
%     (activityEnd[i, fb] <= 
%         vehicleAvailability[activityVehicle[i, fb], any, ShiftEnd] - 
%         requestBoardingDuration[i] - 
%         distMatrix[requestReturn[i], vehicleStart[activityVehicle[i, fb]]]);

% N-1. Given the boolean sameVehicleBackward, we need to ensure it is satisfied

constraint sameVehicleBackward -> forall (i in 1..noRequests)(activityVehicle[i, Forward] = activityVehicle[i, Backward]);


% N. Allow one-trip requests to be granted
% - We'll assume that the activity execution status is 1 for the trip that isn't done.

constraint forall (i in 1..noRequests where requestReturn[i] = -1) (activityExecutionStatus[i, Backward] = 1);
constraint forall (i in 1..noRequests where requestStart[i] = -1) (activityExecutionStatus[i, Forward] = 1);



% ----------------------------------------------

% this 4 arrays could be the auxiliary variables for the output. I think this way we wouldn't need the activityVehicle variable

% array [1..noVehicles, 1..noRequests, 1..noRequests] of var 1..noRequests : vehicleTripPatients; % [ [ [ ], [ 22, 25 ] ] ] - project statement example would be 
% like this. First array inside is to identify the vehicle and the remaining arrays inside that array would be the patients of each trip of that vehicle

% array [1..noVehicles, 1..noRequests] of var 1..noPlaces : vehicleTripOrigin; % array with array inside that would store the origins of each trip for every 
% vehicle. Might need a noTrips variable

% array [1..noVehicles, 1..noRequests] of var 1..noPlaces : vehicleTripDestination; % array with array inside that would store the destinations of each trip for
% every vehicle. Might need a noTrips variable

% array [1..noVehicles, 1..noRequests] of var 0..DAY_IN_MINUTES : vehicleTripArrival; % array with array inside that would store the arrival time of each trip for
% every vehicle.

% ----------------------------------------------