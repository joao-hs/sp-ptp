% Imports

include "cumulative.mzn";

% Parameters

bool : sameVehicleBackward;
int : maxWaitTime;

int : noPlaces;
enum PlaceCategory = {MedicalCenter, VehicleDepot, PatientLocation};
array [0..noPlaces-1] of PlaceCategory : placeCategory;

int : noVehicles;
int : noCategories;
enum ShiftPos = {ShiftStart, ShiftEnd};
array [0..noVehicles-1, 0..noCategories-1] of bool : vehicleCanTake;
array [0..noVehicles-1] of int : vehicleStart;
array [0..noVehicles-1] of int : vehicleEnd;
array [0..noVehicles-1] of int : vehicleCapacity;
array [0..noVehicles-1, ShiftPos] of int : vehicleAvailability;

int : noRequests;
int : noActivities = 2*noRequests;
array [0..noRequests-1] of int : requestStart; % -1 if the patient is already at the medical center
array [0..noRequests-1] of int : requestDestination;
array [0..noRequests-1] of int : requestReturn; % -1 if there's no need to return
array [0..noRequests-1] of int : requestLoad;
array [0..noRequests-1] of int : requestServiceStartTime;
array [0..noRequests-1] of int : requestServiceDuration;
array [0..noRequests-1] of int : requestCategory;
array [0..noRequests-1] of int : requestBoardingDuration;

array [0..noPlaces-1, 0..noPlaces-1] of int : distMatrix;


% Check if parameters are as expected

output ["sameVehicleBackward = ", show(sameVehicleBackward), "\n"];
output ["maxWaitTime = ", show(maxWaitTime), "\n"];

output ["noPlaces = ", show(noPlaces-1), "\n"];
output ["placeCategory = ", show(placeCategory), "\n"];

output ["noVehicles = ", show(noVehicles-1), "\n"];
output ["vehicleCanTake = ", show(vehicleCanTake), "\n"];
output ["vehicleStart = ", show(vehicleStart), "\n"];
output ["vehicleEnd = ", show(vehicleEnd), "\n"];
output ["vehicleCapacity = ", show(vehicleCapacity), "\n"];
output ["vehicleAvailability = ", show(vehicleAvailability), "\n"];

output ["noRequests = ", show(noRequests-1), "\n"];
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
% enum ActivityType = {Forward, Backward};


% Decision Variables

array [0..noActivities-1] of var 0..DAY_IN_MINUTES : activityStart;
array [0..noActivities-1] of var 0..DAY_IN_MINUTES : activityDuration;
array [0..noActivities-1] of var 0..DAY_IN_MINUTES : activityEnd;
array [0..noActivities-1] of var bool : activityExecutionStatus;
array [0..noActivities-1] of var 0..noVehicles-1 : activityVehicle;

function int: forward(int: activity) = activity;
function int: backward(int: activity) = activity + 1;
function int: activityRequest(int: activity) = (activity) div 2;
test isForward(int: activity) = activity mod 2 == 0;
test isBackward(int: activity) = activity mod 2 == 1;
test happens(int: activity) = ((isForward(activity) /\ requestStart[activityRequest(activity)] != -1) \/ (isBackward(activity) /\ requestReturn[activityRequest(activity)] != -1));
test isTwoWayTrip(int: activity) = (requestStart[activityRequest(activity)] != -1 /\ requestReturn[activityRequest(backward(activity))] != -1);

% array [0..noRequests-1, ActivityType] of var 0..DAY_IN_MINUTES : activityStartOld;
% array [0..noRequests-1, ActivityType] of var 0..DAY_IN_MINUTES : activityDurationOld;
% array [0..noRequests-1, ActivityType] of var 0..DAY_IN_MINUTES : activityEndOld;
% array [0..noRequests-1, ActivityType] of var bool : activityExecutionStatusOld;
% array [0..noRequests-1, ActivityType] of var 0..noVehicles-1 : activityVehicleOld;

var 1..noRequests : grantedRequests = count(i in 0..noActivities-1 where isForward(i))(activityExecutionStatus[i] /\ activityExecutionStatus[backward(i)]);

solve maximize grantedRequests;

output ["grantedRequests = ", show(grantedRequests), "\n"];
output ["activityStart = ", show(activityStart), "\n"];
output ["activityDuration = ", show(activityDuration), "\n"];
output ["activityEnd = ", show(activityEnd), "\n"];
output ["activityExecutionStatus = ", show(activityExecutionStatus), "\n"];
output ["activityVehicle = ", show(activityVehicle), "\n"];

% Specific domains as constraints
% Might be optimizable
constraint forall (i in 0..noActivities-1) (
  (
    (isForward(i)) /\
    (activityStart[i] in 0..requestServiceStartTime[activityRequest(i)]) /\
    (activityEnd[i] in 0..requestServiceStartTime[activityRequest(i)]) /\
    (activityDuration[i] = activityEnd[i] - activityStart[i]) /\
    (activityVehicle[i] in {v | v in 0..noVehicles-1 where vehicleCanTake[v, requestCategory[activityRequest(i)]]})
  )
  
  \/

  (
    (isBackward(i)) /\
    (activityStart[i] in (requestServiceStartTime[activityRequest(i)]+requestServiceDuration[activityRequest(i)])..DAY_IN_MINUTES) /\
    (activityEnd[i] in (requestServiceStartTime[activityRequest(i)]+requestServiceDuration[activityRequest(i)])..DAY_IN_MINUTES) /\
    (activityDuration[i] = activityEnd[i] - activityStart[i]) /\
    (activityVehicle[i] in {v | v in 0..noVehicles-1 where vehicleCanTake[v, requestCategory[activityRequest(i)]]})
  )
);

% Constraints

% Binding Requests to Activities
% Maybe  this one isn't necessary since you did it above

% constraint forall(i in 0..noRequests-1) (activityExecutionStatusOld[i, Forward] /\ activityExecutionStatusOld[i, Backward]);

constraint forall(i in 0..noActivities-1 where isForward(i)) (activityExecutionStatus[i] /\ activityExecutionStatus[backward(i)]);

% Forward and Backward Selection

% constraint forall(i in 0..noRequests-1) (activityExecutionStatusOld[i, Forward] = activityExecutionStatusOld[i, Backward]);

constraint forall(i in 0..noActivities-1 where isForward(i) /\ isTwoWayTrip(i)) (activityExecutionStatus[i] = activityExecutionStatus[backward(i)]);

% Inter-Activity Time Travel Consistency
% might something in between each constraint or to create 4 different ones. And not sure what srv is supposed to be I think it's what I wrote maybe it's requestBoardingDuration

% constraint forall(i, j in 0..noRequests-1, t in ActivityType where i != j /\ activityVehicleOld[i, t] = activityVehicleOld[j, t] ) (
%     (activityStartOld[j, t] - activityStartOld[i, t] >= distMatrix[requestStart[i], requestStart[j]] + requestBoardingDuration[i]
%         \/ activityStartOld[i, t] - activityStartOld[j, t] >= distMatrix[requestStart[j], requestStart[i]] + requestBoardingDuration[j])
    
%     /\ (activityStartOld[j, t] - activityEndOld[i, t] >= distMatrix[requestStart[i], requestDestination[j]]                                                           
%         \/ activityEndOld[i, t] - activityStartOld[j, t] >= distMatrix[requestDestination[j], requestStart[i]] + requestBoardingDuration[j] + requestBoardingDuration[i])
    
%     /\ (activityEndOld[j, t] - activityStartOld[i, t] >= distMatrix[requestDestination[i], requestStart[j]] + requestBoardingDuration[i] + requestBoardingDuration[j]
%         \/ activityStartOld[i, t] - activityEndOld[j, t] >= distMatrix[requestStart[j], requestDestination[i]]) 
    
%     /\ (activityEndOld[j, t] - activityEndOld[i, t] >= distMatrix[requestDestination[i], requestDestination[j]] + requestBoardingDuration[j]
%         \/ activityEndOld[i, t] - activityEndOld[j, t] >= distMatrix[requestDestination[j], requestDestination[i]] + requestBoardingDuration[i])
% );

constraint forall(i, j in 0..noActivities-1 where i != j /\ i != backward(j) /\ j != backward(i) /\ activityVehicle[i] = activityVehicle[j] /\ happens(i) /\ happens(j)) (
    ((activityStart[j] - activityStart[i] >= distMatrix[requestStart[activityRequest(i)], requestStart[activityRequest(j)]] + requestBoardingDuration[activityRequest(i)]
        \/ activityStart[i] - activityStart[j] >= distMatrix[requestStart[activityRequest(j)], requestStart[activityRequest(i)]] + requestBoardingDuration[activityRequest(j)]))
    
    /\ ((activityStart[j] - activityEnd[i] >= distMatrix[requestStart[activityRequest(i)], requestDestination[activityRequest(j)]]                                                           
        \/ activityEnd[i] - activityStart[j] >= distMatrix[requestDestination[activityRequest(j)], requestStart[activityRequest(i)]] + requestBoardingDuration[activityRequest(j)] + requestBoardingDuration[activityRequest(i)]))
    
    /\ ((activityEnd[j] - activityStart[i] >= distMatrix[requestDestination[activityRequest(i)], requestStart[activityRequest(j)]] + requestBoardingDuration[activityRequest(i)] + requestBoardingDuration[activityRequest(j)]
        \/ activityStart[i] - activityEnd[j] >= distMatrix[requestStart[activityRequest(j)], requestDestination[activityRequest(i)]])) 
    
    /\ ((activityEnd[j] - activityEnd[i] >= distMatrix[requestDestination[activityRequest(i)], requestDestination[activityRequest(j)]] + requestBoardingDuration[activityRequest(j)]
        \/ activityEnd[i] - activityEnd[j] >= distMatrix[requestDestination[activityRequest(j)], requestDestination[activityRequest(i)]] + requestBoardingDuration[activityRequest(i)]))
);

% Intra-Activity Time Travel Consistency

% constraint forall(i in 0..noRequests-1) (activityDurationOld[i, Forward] >= distMatrix[requestStart[i], requestDestination[i]] /\ activityDurationOld[i, Backward] >= distMatrix[requestDestination[i], requestReturn[i]]);

constraint forall(i in 0..noActivities-1 where isForward(i) /\ happens(i)) (
  (activityDuration[i] >= distMatrix[requestStart[activityRequest(i)], requestDestination[activityRequest(i)]]));

constraint forall(i in 0..noActivities-1 where isForward(i) /\ happens(i)) (
  (activityDuration[backward(i)] >= distMatrix[requestDestination[activityRequest(i)], requestReturn[activityRequest(i)]]));
% Maximum Travel Time - Don't think this is a constraint for our project

% constraint forall(i in 0..noRequests-1) (activityDurationOld[i] <= maxWaitTime)

% Cumulative Resource

constraint forall(j in 0..noVehicles-1, i in 0..noActivities-1 where activityVehicle[i] = j /\ happens(i)) (
  cumulative(
    activityStart,
    activityDuration,
    array1d(0..noActivities-1, [requestLoad[activityRequest(act)] | act in 0..noActivities-1]),
    vehicleCapacity[j])
);

% constraint forall (j in 0..noVehicles-1 where j in [activityVehicleOld[i, t] | i in 0..noRequests-1, t in ActivityType]) (
%   cumulative(
%     [deopt(v) | v in [activityStartOld[i, t] | i in 0..noRequests-1, t in ActivityType where activityVehicleOld[i, t] = j]],
%     [deopt(v) | v in [activityDurationOld[i, t] | i in 0..noRequests-1, t in ActivityType where activityVehicleOld[i, t] = j]],
%     [requestLoad[i] | i in 0..noRequests-1],
%     vehicleCapacity[j]
%   )
% );


% Maximum Waiting Time
% might be optimizable

constraint forall(i in 0..noActivities-1 where happens(i)) (
  (
    isForward(i) /\ 
    (
      (
        (activityStart[i] in 
          0
          ..
          (requestServiceStartTime[activityRequest(i)]-distMatrix[requestStart[activityRequest(i)], requestDestination[activityRequest(i)]]-requestBoardingDuration[activityRequest(i)]-maxWaitTime)
        )
        /\
        (activityEnd[i] in 
          (requestServiceStartTime[activityRequest(i)]-maxWaitTime-requestBoardingDuration[activityRequest(i)])
          ..
          (requestServiceStartTime[activityRequest(i)]-requestBoardingDuration[activityRequest(i)])
        )
      )
    )
  ) 
  \/
  (
    isBackward(i) /\ 
    (
      (
        (activityStart[i] in 
          (requestServiceStartTime[activityRequest(i)]+requestServiceDuration[activityRequest(i)])
          ..
          (requestServiceStartTime[activityRequest(i)]+requestServiceDuration[activityRequest(i)]+maxWaitTime)
        )
        /\
        (activityEnd[i] in 
          (activityStart[i]+distMatrix[requestDestination[activityRequest(i)], requestReturn[activityRequest(i)]])
          ..
          DAY_IN_MINUTES
        )
      )
    )
  )
);

% N-2. Ensure that the activity start and end times are consistent with the vehicle's availability

% constraint forall (i in 0..noRequests-1 where requestStart[i] != -1)
%     (activityStartOld[i, fb] >= 
%         vehicleAvailability[activityVehicleOld[i, fb], any, ShiftStart] + 
%         requestBoardingDuration[i] + 
%         distMatrix[requestStart[i], vehicleStart[activityVehicleOld[i, fb]]] | fb in (Forward, Backward));

% constraint forall (i in 0..noRequests-1 where requestReturn[i] != -1)
%     (activityEndOld[i, fb] <= 
%         vehicleAvailability[activityVehicleOld[i, fb], any, ShiftEnd] - 
%         requestBoardingDuration[i] - 
%         distMatrix[requestReturn[i], vehicleStart[activityVehicleOld[i, fb]]]);


% constraint forall (i in 0..2*noRequests-1) (
%   exists(s in 0..noShifts where i mod 2 == 1)(
%     activityStart[i] >= 
%       vehicleAvailability[activityVehicle[i], s, ShiftStart] + 
%       distMatrix[vehicleStart[activityVehicle[i]],requestStart[i]]
%     /\
%     activityEnd[i] <=
%       vehicleAvailability[activityVehicle[i], s, ShiftEnd] -
%       distMatrix[requestDestination[i], vehicleEnd[activityVehicle[i]]]
%   ) /\
%   exists(s in 0..noShifts where i mod 2 == 0)(
%     activityStart[i] >= 
%       vehicleAvailability[activityVehicle[i], s, ShiftStart] + 
%       distMatrix[vehicleStart[activityVehicle[i]],requestDestination[i]]
%     /\
%     activityEnd[i] <=
%       vehicleAvailability[activityVehicle[i], s, ShiftEnd] -
%       distMatrix[requestReturn[i], vehicleEnd[activityVehicle[i]]]
%   )
% );

constraint forall (i in 0..noActivities-1 where happens(i)) (
  (
    isForward(i) /\ 
    (
      (
        (activityStart[i] >= 
          vehicleAvailability[activityVehicle[i], ShiftStart] +
          distMatrix[vehicleStart[activityVehicle[i]], requestStart[activityRequest(i)]])
      /\
        (activityEnd[i] <=
          vehicleAvailability[activityVehicle[i], ShiftEnd] -
          distMatrix[requestDestination[activityRequest(i)], vehicleEnd[activityVehicle[i]]])
      )
    )
  )
  \/
  (
    isBackward(i) /\ 
    (
      (
        (activityStart[i] >= 
          vehicleAvailability[activityVehicle[i], ShiftStart] +
          distMatrix[vehicleStart[activityVehicle[i]], requestDestination[activityRequest(i)]])
      /\
        (activityEnd[i] <=
          vehicleAvailability[activityVehicle[i], ShiftEnd] -
          distMatrix[requestReturn[activityRequest(i)], vehicleEnd[activityVehicle[i]]])
      )
    )
  )
);

% N-1. Given the boolean sameVehicleBackward, we need to ensure it is satisfied

constraint sameVehicleBackward -> forall (i in 0..noActivities-1 where isForward(i)) (activityVehicle[i] = activityVehicle[backward(i)]);


% N. Allow one-trip requests to be granted
% - We'll assume that the activity execution status is 1 for the trip that isn't done.

constraint forall (i in 0..noActivities-1 where not happens(i)) (activityExecutionStatus[i] = true);



% ----------------------------------------------

% this 4 arrays could be the auxiliary variables for the output. I think this way we wouldn't need the activityVehicleOld variable

% array [0..noVehicles-1, 0..noRequests-1, 0..noRequests-1] of var 0..noRequests-1 : vehicleTripPatients; % [ [ [ ], [ 22, 25 ] ] ] - project statement example would be 
% like this. First array inside is to identify the vehicle and the remaining arrays inside that array would be the patients of each trip of that vehicle

% array [0..noVehicles-1, 0..noRequests-1] of var 0..noPlaces-1 : vehicleTripOrigin; % array with array inside that would store the origins of each trip for every 
% vehicle. Might need a noTrips variable

% array [0..noVehicles-1, 0..noRequests-1] of var 0..noPlaces-1 : vehicleTripDestination; % array with array inside that would store the destinations of each trip for
% every vehicle. Might need a noTrips variable

% array [0..noVehicles-1, 0..noRequests-1] of var 0..DAY_IN_MINUTES : vehicleTripArrival; % array with array inside that would store the arrival time of each trip for
% every vehicle.

% ----------------------------------------------