from json import load, dump
from sys import argv
from minizinc import Driver, Model, Solver, Instance, default_driver

input_name = argv[1]
output_name = argv[2]

input_file = open(input_name, 'r')
output_file = open(output_name, 'w')

data = load(input_file)

model = Model("./ptp.mzn")
solver = Solver.lookup("gecode")
instance = Instance(solver, model)

# Converts a time in the format HHhMM:HHhMM to minutes:minutes
def get_availability(time : str) -> int:
    return (int(time[:2])*60+int(time[3:5]), int(time[6:8])*60+int(time[9:]))

noVehicles = len(data["vehicles"])

vehicleData = dict(
    vehicleId = []*noVehicles,
    vehicleCanTake = []*noVehicles,
    vehicleStart = []*noVehicles,
    vehicleEnd = []*noVehicles,
    vehicleCapacity = []*noVehicles,
    vehicleAvailability = []*noVehicles,
)

for index, v in enumerate(data["vehicle"]):
    vehicleData["vehicleId"][index] = v["id"]
    vehicleData["vehicleCanTake"][index] = v["canTake"]
    vehicleData["vehicleStart"][index] = v["start"]
    vehicleData["vehicleEnd"][index] = v["end"]
    vehicleData["vehicleCapacity"][index] = v["capacity"]
    vehicleData["vehicleAvailability"][index] = get_availability(v["availability"])

result = instance.solve()
