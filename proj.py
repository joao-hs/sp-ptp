from json import load, dump
from sys import argv
from minizinc import Model, Solver, Instance
from numpy import array

# Converts a time in the format HHhMM to minutes
def get_minutes(time : str) -> int:
    return int(time[:2])*60+int(time[3:])

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

instance["sameVehicleBackward"] = data["sameVehicleBackward"]
instance["maxWaitTime"] = get_minutes(data["maxWaitTime"])

noPlaces = len(data["places"])
instance["noPlaces"] = noPlaces
noRequests = len(data["patients"])
instance["noRequests"] = noRequests

requestData = dict(
    requestStart = [0]*noRequests,
    requestDestination = [0]*noRequests,
    requestReturn = [0]*noRequests,
    requestLoad = [0]*noRequests,
    requestServiceStartTime = [0]*noRequests,
    requestServiceDuration = [0]*noRequests,
    requestCategory = [0]*noRequests,
    requestBoardingDuration = [0]*noRequests
)

for index, patient in enumerate(data["patients"]):
    requestData["requestStart"][index] = patient["start"]
    requestData["requestDestination"][index] = patient["destination"]
    requestData["requestReturn"][index] = patient["end"]
    requestData["requestLoad"][index] = patient["load"]
    requestData["requestServiceStartTime"][index] = get_minutes(patient["rdvTime"])
    requestData["requestServiceDuration"][index] = get_minutes(patient["rdvDuration"])
    requestData["requestCategory"][index] = patient["category"]
    requestData["requestBoardingDuration"][index] = get_minutes(patient["srvDuration"])

for key in requestData:
    instance[key] = requestData[key]

instance["noPlaces"] = noPlaces
instance["distMatrix"] = data["distMatrix"]

result = instance.solve()

print(result)