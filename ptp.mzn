% Imports

include "cumulative.mzn";

% Parameters

bool : sameVehicleBackward;
int : maxWaitTime;

int : noPlaces;
enum PlaceCategory = {MedicalCenter, VehicleDepot, PatientLocation};
array [0..noPlaces-1] of PlaceCategory : placeCategory;

int : noOriginalVehicles;
int : noVehicles;
int : noCategories;
enum ShiftPos = {ShiftStart, ShiftEnd};
array [0..noVehicles-1, 0..noCategories-1] of bool : vehicleCanTake;
array [0..noVehicles-1] of int : vehicleStart;
array [0..noVehicles-1] of int : vehicleEnd;
array [0..noVehicles-1] of int : vehicleCapacity;
array [0..noVehicles-1, ShiftPos] of int : vehicleAvailability;
array [0..noVehicles-1] of int : expandedToOriginalVehicle;

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

% output ["sameVehicleBackward = ", show(sameVehicleBackward), "\n"];
% output ["maxWaitTime = ", show(maxWaitTime), "\n"];

% output ["noPlaces = ", show(noPlaces-1), "\n"];
% output ["placeCategory = ", show(placeCategory), "\n"];

% output ["noVehicles = ", show(noVehicles-1), "\n"];
% output ["vehicleCanTake = ", show(vehicleCanTake), "\n"];
% output ["vehicleStart = ", show(vehicleStart), "\n"];
% output ["vehicleEnd = ", show(vehicleEnd), "\n"];
% output ["vehicleCapacity = ", show(vehicleCapacity), "\n"];
% output ["vehicleAvailability = ", show(vehicleAvailability), "\n"];

% output ["noRequests = ", show(noRequests-1), "\n"];
% output ["requestStart = ", show(requestStart), "\n"];
% output ["requestDestination = ", show(requestDestination), "\n"];
% output ["requestReturn = ", show(requestReturn), "\n"];
% output ["requestLoad = ", show(requestLoad), "\n"];
% output ["requestServiceStartTime = ", show(requestServiceStartTime), "\n"];
% output ["requestServiceDuration = ", show(requestServiceDuration), "\n"];
% output ["requestCategory = ", show(requestCategory), "\n"];
% output ["requestBoardingDuration = ", show(requestBoardingDuration), "\n"];

% output ["distMatrix = ", show(distMatrix), "\n"];


% Support for decision variables

int : DAY_IN_MINUTES = 1440; % 24 hours in minutes
enum Status = {Granted, Rejected, NotNeeded};

% Decision Variables

array [0..noActivities-1] of var 0..DAY_IN_MINUTES : activityStart;
array [0..noActivities-1] of var 0..DAY_IN_MINUTES : activityDuration;
array [0..noActivities-1] of var 0..DAY_IN_MINUTES : activityEnd;
array [0..noActivities-1] of var Status : activityExecutionStatus;
array [0..noActivities-1] of var 0..noVehicles-1 : activityVehicle;

function int: forward(int: activity) = activity;
function int: backward(int: activity) = activity + 1;
function int: activityRequest(int: activity) = (activity) div 2;
function int: activityOrigin(int: activity) = if isForward(activity) then requestStart[activityRequest(activity)] else requestDestination[activityRequest(activity)] endif;
function int: activityDestination(int: activity) = if isForward(activity) then requestDestination[activityRequest(activity)] else requestReturn[activityRequest(activity)] endif;
test isForward(int: activity) = activity mod 2 = 0;
test isBackward(int: activity) = activity mod 2 = 1;
test happensForward(int: activity) = requestStart[activityRequest(activity)] != -1;
test happensBackward(int: activity) = requestReturn[activityRequest(activity)] != -1;
test happens(int: activity) = (isForward(activity) /\ happensForward(activity)) \/ (isBackward(activity) /\ happensBackward(activity));
test isTwoWayTrip(int: activity) = (requestStart[activityRequest(activity)] != -1 /\ requestReturn[activityRequest(backward(activity))] != -1);
test fromSameRequest(int: activity1, int: activity2) = activityRequest(activity1) = activityRequest(activity2);
predicate simultaneous(int: activity1, int: activity2) = (activityStart[activity1] < activityStart[activity2] /\ activityEnd[activity1] > activityStart[activity2]) \/ (activityStart[activity2] < activityStart[activity1] /\ activityEnd[activity2] > activityStart[activity1]);

var 0..noRequests : grantedRequests = count(i in 0..noActivities-1 where isForward(i))(activityExecutionStatus[i] != Rejected /\ activityExecutionStatus[backward(i)] != Rejected);

solve maximize grantedRequests;

output ["grantedRequests = ", show(grantedRequests), "\n"];
output ["activityStart = ", show(activityStart), "\n"];
output ["activityDuration = ", show(activityDuration), "\n"];
output ["activityEnd = ", show(activityEnd), "\n"];
output ["activityExecutionStatus = ", show(activityExecutionStatus), "\n"];
output ["activityVehicle = ", show(activityVehicle), "\n"];

% Constraints

% 0. Specific domains as constraints
% Might be optimizable

constraint forall (i in 0..noActivities-1 where happens(i) /\ activityExecutionStatus[i] == Granted) (
  (activityDuration[i] = activityEnd[i] - activityStart[i]) /\
  (activityVehicle[i] in {v | v in 0..noVehicles-1 where vehicleCanTake[v, requestCategory[activityRequest(i)]]})
  /\ trace("(0)", true)
);

constraint redundant_constraint(
  forall(i in 0..noActivities-1 where isForward(i) /\ happensForward(i) /\ activityExecutionStatus[i] == Granted)(
    activityStart[i] < activityEnd[i]
    /\
    activityEnd[i] < activityStart[backward(i)]
    /\
    activityStart[backward(i)] < activityEnd[backward(i)]
  )
  /\ trace("(-1)", true)
);

% 1. Forward and Backward Selection
% dont think we need this one because of the last constraint

constraint forall(i in 0..noActivities-1 where isForward(i) /\ isTwoWayTrip(i)) (activityExecutionStatus[i] = activityExecutionStatus[backward(i)] /\ trace("(1)", true));

% 2. Inter-Activity Time Travel Consistency

constraint forall(i, j in 0..noActivities-1 where i != j /\ expandedToOriginalVehicle[activityVehicle[i]] = expandedToOriginalVehicle[activityVehicle[j]] /\ happens(i) /\ happens(j) /\ activityExecutionStatus[i] == Granted /\ activityExecutionStatus[j] == Granted) (
  (
    activityStart[j] - activityStart[i] >= distMatrix[activityOrigin(i), activityOrigin(j)] + requestBoardingDuration[activityRequest(i)] 
    \/ 
    activityStart[i] - activityStart[j] >= distMatrix[activityOrigin(j), activityOrigin(i)] + requestBoardingDuration[activityRequest(j)]
  )
  /\
  (
    activityStart[j] - activityEnd[i] >= distMatrix[activityDestination(i), activityOrigin(j)]
    \/
    activityEnd[i] - activityStart[j] >= distMatrix[activityOrigin(j), activityDestination(i)] + requestBoardingDuration[activityRequest(j)] + requestBoardingDuration[activityRequest(i)]
  )
  /\
  (
    activityEnd[j] - activityStart[i] >= distMatrix[activityOrigin(i), activityDestination(j)] + requestBoardingDuration[activityRequest(i)] + requestBoardingDuration[activityRequest(j)]
    \/
    activityStart[i] - activityEnd[j] >= distMatrix[activityDestination(j), activityOrigin(i)]
  )
  /\
  (
    activityEnd[j] - activityEnd[i] >= distMatrix[activityDestination(i), activityDestination(j)] + requestBoardingDuration[activityRequest(j)]
    \/
    activityEnd[i] - activityEnd[j] >= distMatrix[activityDestination(j), activityDestination(i)] + requestBoardingDuration[activityRequest(i)]
  )
  /\ trace("(2)", true)
);

% 3. Intra-Activity Time Travel Consistency

constraint forall(i in 0..noActivities-1 where happens(i) /\ activityExecutionStatus[i] == Granted) (
  activityDuration[i] >= distMatrix[activityOrigin(i), activityDestination(i)] + 2 * requestBoardingDuration[activityRequest(i)]
  /\ trace("(3)", true)
);

% 4. Cumulative Resource

constraint forall(j in 0..noVehicles-1) (
  cumulative(
    activityStart,
    activityDuration,
    array1d(0..noActivities-1, [if act in vehicleActivities then requestLoad[activityRequest(act)] else 0 endif | act in 0..noActivities-1, vehicleActivities = {i | i in 0..noActivities-1 where activityVehicle[i] = j /\ happens(i) /\ activityExecutionStatus[i] == Granted}]),
    vehicleCapacity[j]
  )
  /\ trace("(4)", true)
);

% 5. Maximum Waiting Time

constraint forall(i in 0..noActivities-1 where isForward(i) /\ happensForward(i) /\ activityExecutionStatus[i] == Granted) (
  (activityStart[i] in 
    % minimum case: we use all the maxWaitTime
    (requestServiceStartTime[activityRequest(i)] - maxWaitTime)
    ..
    % maximum case: the vehicle arrives the patient's start location and goes directly to the medical center
    (requestServiceStartTime[activityRequest(i)] - 2*requestBoardingDuration[activityRequest(i)] - distMatrix[requestDestination[activityRequest(i)], requestStart[activityRequest(i)]])
  )
  /\
  (activityEnd[i] in 
    % minimum case: the vehicle goes directly to the medical center and leaves
    (activityStart[i] + 2*requestBoardingDuration[activityRequest(i)] + distMatrix[requestStart[activityRequest(i)], requestDestination[activityRequest(i)]])
    ..
    % maximum case: the vehicle leaves the patient just in time for the appointment
    (requestServiceStartTime[activityRequest(i)])
  )
  /\ trace("(5.2)", true)
);

constraint forall(i in 0..noActivities-1 where isBackward(i) /\ happensBackward(i) /\ activityExecutionStatus[i] == Granted) (
  (activityStart[i] in 
    % minimum case: vehicle arrives the medical center at the end of the patient's appointment
    (requestServiceStartTime[activityRequest(i)] + requestServiceDuration[activityRequest(i)])
    ..
    % maximum case: vehicle goes directly to patient's return place
    (activityEnd[i] - 2*requestBoardingDuration[activityRequest(i)] - distMatrix[requestDestination[activityRequest(i)], requestReturn[activityRequest(i)]])
  )
  /\
  (activityEnd[i] in 
    % minimum case: vehicle goes directly to patient's return place
    (requestServiceStartTime[activityRequest(i)] + requestServiceDuration[activityRequest(i)] + 2*requestBoardingDuration[activityRequest(i)] + distMatrix[requestDestination[activityRequest(i)], requestReturn[activityRequest(i)]])
    ..
    % maximum case: we use all the maximum wait time
    (requestServiceStartTime[activityRequest(i)] + requestServiceDuration[activityRequest(i)] + maxWaitTime)
  )
  /\ trace("(5.3)", true)
);

% 5.1. Ensure that maxWaitTime is enought to satisfy the request
constraint forall(i in 0..noActivities-1 where happens(i)) (
  if maxWaitTime < 2*requestBoardingDuration[activityRequest(i)] + distMatrix[activityOrigin(i), activityDestination(i)] 
    then activityExecutionStatus[i] = Rejected 
  else true 
  endif
  /\ trace("(5.1)", true)
);

% 6. Ensure that the activity start and end times are consistent with the vehicle's availability

constraint forall (i in 0..noActivities-1 where happens(i) /\ activityExecutionStatus[i] == Granted) (
  (activityStart[i] >= vehicleAvailability[activityVehicle[i], ShiftStart]
    + distMatrix[vehicleStart[activityVehicle[i]], activityOrigin(i)])
  /\
  (activityEnd[i] <= vehicleAvailability[activityVehicle[i], ShiftEnd]
    - distMatrix[activityDestination(i), vehicleEnd[activityVehicle[i]]])
  /\ trace("(6.2)", true)
);

% 6.1. Vehicles that can't reach the activity's origin or destination in time can't be assigned to it
constraint forall (v in 0..noVehicles-1, i in 0..noActivities-1 where happens(i) /\ vehicleCanTake[v, requestCategory[activityRequest(i)]] /\ activityExecutionStatus[i] == Granted) (
  if activityStart[i] < vehicleAvailability[v, ShiftStart] + distMatrix[vehicleStart[v], activityOrigin(i)] \/ activityEnd[i] > vehicleAvailability[v, ShiftEnd] + distMatrix[activityDestination(i), vehicleEnd[v]]
    then activityVehicle[i] != v 
  else true
  endif
  /\ trace("(6.1)", true)
);

% 7. Given the boolean sameVehicleBackward, we need to ensure it is satisfied

constraint sameVehicleBackward -> forall (i in 0..noActivities-1 where isForward(i) /\ happensForward(i) /\ happensBackward(backward(i)) /\ activityExecutionStatus[i] == Granted) (expandedToOriginalVehicle[activityVehicle[i]] = expandedToOriginalVehicle[activityVehicle[backward(i)]] /\ trace("(7)", true));

% 8. Allow one-trip requests to be granted
% - We'll assume that the activity execution status is true for the trip that isn't done.

constraint forall (i in 0..noActivities-1) (if happens(i) then activityExecutionStatus[i] != NotNeeded else activityExecutionStatus[i] = NotNeeded endif /\ trace("(8)", true));

% ----------------------------------------------

% this 4 arrays could be the auxiliary variables for the output. This might be useful if we find that Python is slow to process the output

% array [0..noVehicles-1, 0..noRequests-1, 0..noRequests-1] of var 0..noRequests-1 : vehicleTripPatients; % [ [ [ ], [ 22, 25 ] ] ] - project statement example would be 
% like this. First array inside is to identify the vehicle and the remaining arrays inside that array would be the patients of each trip of that vehicle

% array [0..noVehicles-1, 0..noRequests-1] of var 0..noPlaces-1 : vehicleTripOrigin; % array with array inside that would store the origins of each trip for every 
% vehicle. Might need a noTrips variable

% array [0..noVehicles-1, 0..noRequests-1] of var 0..noPlaces-1 : vehicleTripDestination; % array with array inside that would store the destinations of each trip for
% every vehicle. Might need a noTrips variable

% array [0..noVehicles-1, 0..noRequests-1] of var 0..DAY_IN_MINUTES : vehicleTripArrival; % array with array inside that would store the arrival time of each trip for
% every vehicle.

% ----------------------------------------------

