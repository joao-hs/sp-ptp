
bool : sameVehicleBackward;
int : maxWaitTime;

int : noPlaces;
int : noRequests;

array [1..noRequests] of int : requestStart;
array [1..noRequests] of int : requestDestination;
array [1..noRequests] of int : requestReturn;        % -1 if there's no need to return
array [1..noRequests] of int : requestLoad;
array [1..noRequests] of int : requestServiceStartTime;
array [1..noRequests] of int : requestServiceDuration;
array [1..noRequests] of int : requestCategory;
array [1..noRequests] of int : requestBoardingDuration;

array [1..noPlaces, 1..noPlaces] of int : distMatrix;


output ["sameVehicleBackward = ", show(sameVehicleBackward), "\n"];
output ["maxWaitTime = ", show(maxWaitTime), "\n"];
output ["noPlaces = ", show(noPlaces), "\n"];
output ["noRequests = ", show(noRequests), "\n"];
output ["requestStart = ", show(requestStart), "\n"];
output ["requestDestination = ", show(requestDestination), "\n"];
output ["requestReturn = ", show(requestReturn), "\n"];
output ["requestLoad = ", show(requestLoad), "\n"];
output ["requestServiceStartTime = ", show(requestServiceStartTime), "\n"];
output ["requestServiceDuration = ", show(requestServiceDuration), "\n"];
output ["requestCategory = ", show(requestCategory), "\n"];
output ["requestBoardingDuration = ", show(requestBoardingDuration), "\n"];
output ["distMatrix = ", show(distMatrix), "\n"]

% int : noPlaces;
% int : id_places_start = 0;
% int : id_places_end = no_places-1;
% array [id_places_start..id_places_end] of int : places;

% int : no_patients_categories;
% int : max_availability_partitions;
int : noVehicles;
int : noShifts;
array [1..noVehicles] of int : vehicleCanTake;
array [1..noVehicles] of int : vehicleStart;
array [1..noVehicles] of int : vehicleEnd;
array [1..noVehicles] of int : vehicleCapacity;
array [1..noVehicles, 1..noShifts, 1..2] of int : vehicleAvailability;

output ["noVehicles = ", show(noVehicles), "\n"];
output ["noShifts = ", show(noShifts), "\n"];
output ["vehicleCanTake = ", show(vehicleCanTake), "\n"];
output ["vehicleStart = ", show(vehicleStart), "\n"];
output ["vehicleEnd = ", show(vehicleEnd), "\n"];
output ["vehicleCapacity = ", show(vehicleCapacity), "\n"];
output ["vehicleAvailability = ", show(vehicleAvailability), "\n"];

% int : no_patients;
% int : id_patients_start = id_vehicle_end+1;
% int : id_patients_end = id_patients_start + no_patients;
% array [id_patients_start..id_patients_end] of int : patients_category;
% array [id_patients_start..id_patients_end] of int : patients_load;
% array [id_patients_start..id_patients_end] of int : patients_start;
% array [id_patients_start..id_patients_end] of int : patients_destination;
% array [id_patients_start..id_patients_end] of int : patients_end;
% array [id_patients_start..id_patients_end] of int : patients_rdvTime;
% array [id_patients_start..id_patients_end] of int : patients_rdvDuration;
% array [id_patients_start..id_patients_end] of int : patients_srvDuration;

% array [id_places_start..id_places_end,id_places_start..id_places_end] of int : distMatrix;


