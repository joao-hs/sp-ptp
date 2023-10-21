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
array [0..noVehicles-1] of int : expandedToOriginalVehicle;

int : noRequests;
array [0..noRequests-1] of int : requestStart; % -1 if the patient is already at the medical center
array [0..noRequests-1] of int : requestDestination;
array [0..noRequests-1] of int : requestReturn; % -1 if there's no need to return
array [0..noRequests-1] of int : requestLoad;
array [0..noRequests-1] of int : requestServiceStartTime;
array [0..noRequests-1] of int : requestServiceDuration;
array [0..noRequests-1] of int : requestCategory;
array [0..noRequests-1] of int : requestBoardingDuration;

array [-1..noPlaces-1, -1..noPlaces-1] of int : distMatrix;

% Support for decision variables

int : DAY_IN_MINUTES = 1440; % 24 hours in minutes

% Decision Variables

int : noActivities = 2*noRequests;
enum Status = {Granted, Rejected, NotNeeded};
array [0..noActivities-1] of var 0..DAY_IN_MINUTES : activityStart;
array [0..noActivities-1] of var 0..maxWaitTime : activityDuration;
array [0..noActivities-1] of var 0..DAY_IN_MINUTES : activityEnd;
array [0..noActivities-1] of var Status : activityExecutionStatus;
array [0..noActivities-1] of var 0..noVehicles-1 : activityVehicle;

function int: forward(int: activity) = activity;
function int: backward(int: activity) = activity + 1;
test isForward(int: activity) = activity mod 2 = 0;
test isBackward(int: activity) = activity mod 2 = 1;
function int: activityOrigin(int: activity) = if isForward(activity) then requestStart[activityRequest(activity)] else requestDestination[activityRequest(activity)] endif;
function int: activityDestination(int: activity) = if isForward(activity) then requestDestination[activityRequest(activity)] else requestReturn[activityRequest(activity)] endif;
function int: activityRequest(int: activity) = (activity) div 2;
test happensForward(int: activity) = requestStart[activityRequest(activity)] != -1;
test happensBackward(int: activity) = requestReturn[activityRequest(activity)] != -1;
test happens(int: activity) = (isForward(activity) /\ happensForward(activity)) \/ (isBackward(activity) /\ happensBackward(activity));
test isTwoWayTrip(int: activity) = (requestStart[activityRequest(activity)] != -1 /\ requestReturn[activityRequest(backward(activity))] != -1);
test fromSameRequest(int: activity1, int: activity2) = activityRequest(activity1) = activityRequest(activity2);
predicate simultaneous(int: activity1, int: activity2) = (activityStart[activity1] < activityStart[activity2] /\ activityEnd[activity1] > activityStart[activity2]) \/ (activityStart[activity2] < activityStart[activity1] /\ activityEnd[activity2] > activityStart[activity1]);

var 0..noRequests : grantedRequests = count(i in 0..noActivities-1 where isForward(i))(activityExecutionStatus[i] != Rejected /\ activityExecutionStatus[backward(i)] != Rejected);

solve :: int_search(activityStart, input_order, indomain_min)
  maximize grantedRequests;

output ["grantedRequests = ", show(grantedRequests), "\n"];
output ["activityStart = ", show(activityStart), "\n"];
output ["activityDuration = ", show(activityDuration), "\n"];
output ["activityEnd = ", show(activityEnd), "\n"];
output ["activityExecutionStatus = ", show(activityExecutionStatus), "\n"];
output ["activityVehicle = ", show(activityVehicle), "\n"];

% Constraints

% 0. Specific domains as constraints

constraint forall (i in 0..noActivities-1 where happens(i) /\ activityExecutionStatus[i] == Granted) (
  (activityDuration[i] = activityEnd[i] - activityStart[i]) /\
  (activityVehicle[i] in {v | v in 0..noVehicles-1 where vehicleCanTake[v, requestCategory[activityRequest(i)]]})
);

constraint redundant_constraint(
  forall(i in 0..noActivities-1 where isForward(i) /\ happensForward(i) /\ activityExecutionStatus[i] == Granted)(
    activityStart[i] < activityEnd[i]
    /\
    activityEnd[i] < activityStart[backward(i)]
    /\
    activityStart[backward(i)] < activityEnd[backward(i)]
  )
);

% 1. Forward and Backward Selection

constraint forall(i in 0..noActivities-1 where isForward(i) /\ isTwoWayTrip(i)) (activityExecutionStatus[i] = activityExecutionStatus[backward(i)]);

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
);

% 3. Intra-Activity Time Travel Consistency

constraint forall(i in 0..noActivities-1 where happens(i) /\ activityExecutionStatus[i] == Granted) (
  activityDuration[i] >= distMatrix[activityOrigin(i), activityDestination(i)] + 2 * requestBoardingDuration[activityRequest(i)]
);

% 4. Cumulative Resource

constraint forall(j in 0..noVehicles-1) (
  let {var set of int : vehicleActivities = {i | i in 0..noActivities-1 where activityVehicle[i] = j /\ happens(i) /\ activityExecutionStatus[i] == Granted}}
  in
  cumulative(
    activityStart,
    activityDuration,
    array1d(0..noActivities-1, [if act in vehicleActivities then requestLoad[activityRequest(act)] else 0 endif | act in 0..noActivities-1]),
    vehicleCapacity[j]
  )
);

% 5. Maximum Waiting Time

constraint forall(i in 0..noActivities-1 where isForward(i) /\ happensForward(i) /\ activityExecutionStatus[i] == Granted) (
  (activityStart[i] in 
    % minimum case: we use all the maxWaitTime
    (requestServiceStartTime[activityRequest(i)] - maxWaitTime)
    ..
    % maximum case: the vehicle arrives the patient's start location and goes directly to the medical center
    (requestServiceStartTime[activityRequest(i)] - 2*requestBoardingDuration[activityRequest(i)] - distMatrix[requestStart[activityRequest(i)], requestDestination[activityRequest(i)]])
  )
  /\
  (activityEnd[i] in 
    % minimum case: the vehicle goes directly to the medical center and leaves
    (activityStart[i] + 2*requestBoardingDuration[activityRequest(i)] + distMatrix[requestStart[activityRequest(i)], requestDestination[activityRequest(i)]])
    ..
    % maximum case: the vehicle leaves the patient just in time for the appointment
    (requestServiceStartTime[activityRequest(i)])
  )
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
);

% 5.1. Ensure that maxWaitTime is enought to satisfy the request
constraint forall(i in 0..noActivities-1 where happens(i)) (
  if maxWaitTime < 2*requestBoardingDuration[activityRequest(i)] + distMatrix[activityOrigin(i), activityDestination(i)] 
    then activityExecutionStatus[i] = Rejected 
  else true 
  endif
);

% 6. Ensure that the activity start and end times are consistent with the vehicle's availability

constraint forall (i in 0..noActivities-1 where happens(i) /\ activityExecutionStatus[i] == Granted) (
  (activityStart[i] >= vehicleAvailability[activityVehicle[i], ShiftStart]
    + distMatrix[vehicleStart[activityVehicle[i]], activityOrigin(i)])
  /\
  (activityEnd[i] <= vehicleAvailability[activityVehicle[i], ShiftEnd]
    - distMatrix[activityDestination(i), vehicleEnd[activityVehicle[i]]])
);

% 6.1. Vehicles that can't reach the activity's origin or destination in time can't be assigned to it
constraint forall (v in 0..noVehicles-1, i in 0..noActivities-1 where happens(i) /\ vehicleCanTake[v, requestCategory[activityRequest(i)]] /\ activityExecutionStatus[i] == Granted) (
  if activityStart[i] < vehicleAvailability[v, ShiftStart] + distMatrix[vehicleStart[v], activityOrigin(i)] \/ activityEnd[i] > vehicleAvailability[v, ShiftEnd] + distMatrix[activityDestination(i), vehicleEnd[v]]
    then activityVehicle[i] != v 
  else true
  endif
);

% 7. Given the boolean sameVehicleBackward, we need to ensure it is satisfied

constraint sameVehicleBackward -> forall (i in 0..noActivities-1 where isForward(i) /\ happensForward(i) /\ happensBackward(backward(i)) /\ activityExecutionStatus[i] == Granted) (expandedToOriginalVehicle[activityVehicle[i]] = expandedToOriginalVehicle[activityVehicle[backward(i)]]);

% 8. Allow one-trip requests to be granted
% - We'll assume that the activity execution status is true for the trip that isn't done.

constraint forall (i in 0..noActivities-1) (if happens(i) then activityExecutionStatus[i] != NotNeeded else activityExecutionStatus[i] = NotNeeded endif);