
bool : sameVehicleBackward;
int : maxWaitTime; % in minutes

int : no_places;
int : id_places_start = 0;
int : id_places_end = no_places-1;
array [id_places_start..id_places_end] of int : places;

int : no_patients_categories;
int : max_availability_partitions;
int : no_vehicles;
int : id_vehicle_start = id_places_end+1;
int : id_vehicle_end = id_vehicle_start+no_vehicles-1;
array [id_vehicle_start..id_vehicle_end, 0..no_patients_categories-1] of 
  int : vehicles_canTake;
array [id_vehicle_start..id_vehicle_end] of int : vehicles_start;
array [id_vehicle_start..id_vehicle_end] of int : vehicles_end;
array [id_vehicle_start..id_vehicle_end] of int : vehicles_capacity;
array [id_vehicle_start..id_vehicle_end, 0..max_availability_partitions-1, 0..1] of 
  int : vehicles_availability;

int : no_patients;
int : id_patients_start = id_vehicle_end+1;
int : id_patients_end = id_patients_start + no_patients;
array [id_patients_start..id_patients_end] of int : patients_category;
array [id_patients_start..id_patients_end] of int : patients_load;
array [id_patients_start..id_patients_end] of int : patients_start;
array [id_patients_start..id_patients_end] of int : patients_destination;
array [id_patients_start..id_patients_end] of int : patients_end;
array [id_patients_start..id_patients_end] of int : patients_rdvTime;
array [id_patients_start..id_patients_end] of int : patients_rdvDuration;
array [id_patients_start..id_patients_end] of int : patients_srvDuration;

array [id_places_start..id_places_end,id_places_start..id_places_end] of int : distMatrix;


