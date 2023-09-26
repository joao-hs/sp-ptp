
bool : sameVehicleBackward;
int : maxWaitTime;

int : noPlaces;
array [1..noPlaces] of int : placeCategory;

int : noVehicles;
int : noShifts;
int : noCategories;
array [1..noVehicles, 1..noCategories] of int : vehicleCanTake;
array [1..noVehicles] of int : vehicleStart;
array [1..noVehicles] of int : vehicleEnd;
array [1..noVehicles] of int : vehicleCapacity;
array [1..noVehicles, 1..noShifts, 1..2] of int : vehicleAvailability;

int : noRequests;
array [1..noRequests] of int : requestStart;
array [1..noRequests] of int : requestDestination;
array [1..noRequests] of int : requestReturn; % -1 if there's no need to return
array [1..noRequests] of int : requestLoad;
array [1..noRequests] of int : requestServiceStartTime;
array [1..noRequests] of int : requestServiceDuration;
array [1..noRequests] of int : requestCategory;
array [1..noRequests] of int : requestBoardingDuration;

array [1..noPlaces, 1..noPlaces] of int : distMatrix;

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
