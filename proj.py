from json import load, dump
from sys import argv
from minizinc import Model, Solver, Instance

input_name = argv[1]
output_name = argv[2]

input_file = open(input_name, 'r')
output_file = open(output_name, 'w')

data = load(input_file)

model = Model("./ptp.mzn")
solver = Solver.lookup("gecode")
instance = Instance(solver, model)

instance["distMatrix"] = None
instance["maxWaitTime"] = None
instance["max_availability_partitions"] = None
instance["no_patients"] = None
instance["no_patients_categories"] = None
instance["no_places"] = None
instance["no_vehicles"] = None
instance["patients_categories"] = None
instance["patients_destination"] = None
instance["patients_end"] = None
instance["patients_load"] = None
instance["patients_rdvDuration"] = None
instance["patients_rdvTime"] = None
instance["patients_srvDuration"] = None
instance["patients_start"] = None
instance["places"] = None
instance["sameVehicleBackward"] = None
instance["vehicles_availability"] = None
instance["vehicles_canTake"] = None
instance["vehicles_capacity"] = None
instance["vehicles_end"] = None
instance["vehicles_start"] = None

result = instance.solve()
output = dump("Hello, world!")
# output = json.dumps({
#     "requests": result["requests"],
#     "vehicles": [
#         {
#             "id": i,
#             "trips": [
#                 {
#                     "origin": origin,
#                     "destination": destination,
#                     "arrival": arrival,
#                     "patients": [
#                         patient_id for patient_id in 
#                     ]
#                 }
#                 for origin, destination, arrival in 
#             ]
#         }
#         for i in range(result["n_vehicles"])
#     ]
# })

print(output, file=output_file)