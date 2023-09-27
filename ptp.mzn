% Parameters

bool : sameVehicleBackward;
int : maxWaitTime;

int : noPlaces;
enum PlaceCategory = {MedicalCenter, VehicleDepot, PatientLocation} 
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

array [1..noRequests, ActivityType] of var 0..DAY_IN_MINUTES : activityStart;
array [1..noRequests, ActivityType] of var 0..DAY_IN_MINUTES : activityDuration;
array [1..noRequests, ActivityType] of var 0..DAY_IN_MINUTES : activityEnd; % start + duration, may be irrelevant
array [1..noRequests, ActivityType] of var bool : activityExecutionStatus;
array [1..noRequests, ActivityType] of var 0..noVehicles : activityVehicle;

% this 4 arrays could be the auxiliary variables for the output. I think this way we wouldn't need the activityVehicle variable

array [1..noVehicles, 1..noRequests, 1..noRequests] of var 1..noRequests : vehicleTripPatients; % [ [ [ ], [ 22, 25 ] ] ] - project statement example would be 
% like this. First array inside is to identify the vehicle and the remaining arrays inside that array would be the patients of each trip of that vehicle

array [1..noVehicles, 1..noRequests] of var 1..noPlaces : vehicleTripOrigin; % array with array inside that would store the origins of each trip for every 
% vehicle. Might need a noTrips variable

array [1..noVehicles, 1..noRequests] of var 1..noPlaces : vehicleTripDestination; % array with array inside that would store the destinations of each trip for
% every vehicle. Might need a noTrips variable

array [1..noVehicles, 1..noRequests] of var 0..DAY_IN_MINUTES : vehicleTripArrival; % array with array inside that would store the arrival time of each trip for
% every vehicle.

% activityStart = [|1,4,|3,7|]
% activityDuration = [|1,1,|3,1|]
% activityEnd = [|2,5,|6,8|]
% activityExecutionStatus = [|true,true,|true,true|]
% activityVehicle = [|1,1,|1,1|]


% {
%     "requests": 2, % count activityExecutionStatus lines with all true
%     "vehicles": [
%         {
%             "id": 5, % id of the vehicle in Minizinc + noPlaces
%             "trips": [
%                 {
%                     "origin": 2, % first trip's origin is the vehicle's depot
%                     "destination": 3, % requestStart of the first activity
%                     "arrival": "11h45",
%                     "patients": []
%                 },
%                 {
%                     "origin": 3, % previous destination
%                     "destination": 0, % for every activity of the vehicle, destination is the (i+1)-th activity's origin
%                     "arrival": "12h00",
%                     "patients": [6] % patient's id = activity's id in minizinc + noPlaces + noVehicles
%                 },
%                 {
%                     "origin": 0, % previous destination
%                     "destination": 4,
%                     "arrival": "12h05",
%                     "patients": []
%                 },
%                 {
%                     "origin": 4,
%                     "destination": 0,
%                     "arrival": "12h10",
%                     "patients": [7]
%                 },
%                 {
%                     "origin": 0,
%                     "destination": 3,
%                     "arrival": "12h",
%                     "patients": []
%                 }
%             ]
%         }
%     ]
% }