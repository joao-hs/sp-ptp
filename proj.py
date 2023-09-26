from json import load, dump
from sys import argv
from minizinc import Model, Solver, Instance


# -----------------------------------------------------------------------------
# ----------------------------- Support Functions -----------------------------
# -----------------------------------------------------------------------------

# Converts a time in the format HHhMM to minutes
def get_minutes(time : str) -> int:
    return int(time[:2])*60+int(time[3:])

# Converts a time in the format HHhMM:HHhMM to [minutes,minutes]
def get_availability(time : str) -> list:
    return [int(time[:2])*60+int(time[3:5]), int(time[6:8])*60+int(time[9:])]


# -----------------------------------------------------------------------------
# ----------------------------------- Setup -----------------------------------
# -----------------------------------------------------------------------------

input_name = argv[1]
output_name = argv[2]

input_file = open(input_name, 'r')
output_file = open(output_name, 'w')

data = load(input_file)

model = Model("./ptp.mzn")
solver = Solver.lookup("gecode")
instance = Instance(solver, model)


# -----------------------------------------------------------------------------
# ------------------------ Parse Input & Assign Values ------------------------
# -----------------------------------------------------------------------------

instance["sameVehicleBackward"] = data["sameVehicleBackward"]
instance["maxWaitTime"] = get_minutes(data["maxWaitTime"])

noPlaces = len(data["places"])
instance["noPlaces"] = noPlaces
instance["placeCategory"] = [place["category"] for place in data["places"]]

noVehicles = len(data["vehicles"])
instance["noVehicles"] = noVehicles

vehicleData = dict(
    vehicleCanTake = [0]*noVehicles,
    vehicleStart = [0]*noVehicles,
    vehicleEnd = [0]*noVehicles,
    vehicleCapacity = [0]*noVehicles,
    vehicleAvailability = [[[0,0]]]*noVehicles,
)

noShifts = 0
noCategories = 0

for index, vehicle in enumerate(data["vehicles"]):
    vehicleData["vehicleCanTake"][index] = vehicle["canTake"]
    noCategories = max(noCategories, len(vehicle["canTake"]))
    vehicleData["vehicleStart"][index] = vehicle["start"]
    vehicleData["vehicleEnd"][index] = vehicle["end"]
    vehicleData["vehicleCapacity"][index] = vehicle["capacity"]
    vehicleData["vehicleAvailability"][index] = [get_availability(i) for i in vehicle["availability"]]
    noShifts = max(noShifts, len(vehicle["availability"]))

instance["noShifts"] = noShifts
instance["noCategories"] = noCategories

for key in vehicleData:
    instance[key] = vehicleData[key]

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

instance["distMatrix"] = data["distMatrix"]


# -----------------------------------------------------------------------------
# --------------------------- Solve & Parse Output ----------------------------
# -----------------------------------------------------------------------------

result = instance.solve()   

print(result)