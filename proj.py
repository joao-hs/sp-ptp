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

# Converts 0,1,2 to MedicalCenter,VehicleDepot,PatientLocation
def get_place_category(place : int) -> str:
    return "MedicalCenter" if place == 0 else "VehicleDepot" if place == 1 else "PatientLocation"

# Aggregates the output of the model into a list of trips by vehicle
def get_trips_by_vehicle(activityStart : list, activityEnd : list, activityVehicle: list) -> dict:
    global noVehicles, noTrueVehicles, noRequests

    vehicleTripsAux = {i:list() for i in range(noVehicles)}

    # auxiliary tuple ~ (location, arrival, associatedPatient)
    vehicleTrips = {
        i: list() for i in range(noTrueVehicles)
    }
    for partialActivity, (actStart, actEnd, actVehicle) in enumerate(zip(activityStart, activityEnd, activityVehicle)):
        patient = partialActivity // 2
        if partialActivity % 2 == 0: # forward
            if requestData["requestStart"][patient] != -1:
                vehicleTripsAux[actVehicle].append((requestData["requestStart"][patient], actStart, patient)) 
                vehicleTripsAux[actVehicle].append((requestData["requestDestination"][patient], actEnd, patient))               
        else: # backward
            if requestData["requestReturn"][patient] != -1:
                vehicleTripsAux[actVehicle].append((requestData["requestDestination"][patient], actStart, patient))
                vehicleTripsAux[actVehicle].append((requestData["requestReturn"][patient], actEnd, patient))


    onboardPatients = set()
    for vehicleIndex in range(noTrueVehicles):
        tripsForVehicle = [trip 
                           for vehicleShift in range(vehiclesIdToIndexRange[vehiclesIndexToId[vehicleIndex]][0], vehiclesIdToIndexRange[vehiclesIndexToId[vehicleIndex]][1]+1) 
                            for trip in vehicleTripsAux[vehicleShift]]
        if not tripsForVehicle:
            continue
        
        tripsForVehicle.sort(key=lambda x: x[1])

        # vehicleTripsAux[vehicle].sort(key=lambda x: x[1]) # sort by arrival time
        # trip tuple ~ (origin, destination, arrival, patients)
        (origin, arrival, patient) = tripsForVehicle.pop(0)
        vehicleTrips[vehicleIndex].append((vehicleData["vehicleStart"][vehicleIndex], origin, arrival-requestData["requestBoardingDuration"][patient], set())) # first trip is from vehicle start to first patient
        onboardPatients.add(patient) # first patient gets onboard
        
        while tripsForVehicle:
            (destination, arrival, patient) = tripsForVehicle.pop(0)
            vehicleTrips[vehicleIndex].append((origin, destination, arrival, onboardPatients.copy()))
            if patient in onboardPatients: # if the activity is associated with the patient and they are onboard, they are now offboarding
                onboardPatients.remove(patient)
            else: # otherwise, they are now onboarding
                onboardPatients.add(patient)
            origin=destination # the next origin is the current destination
        
        vehicleTrips[vehicleIndex].append((
            origin, 
            vehicleData["vehicleEnd"][vehicleIndex],
            arrival+ # last arrival time plus
            requestData["requestBoardingDuration"][patient]+ # the offboarding time of the last patient plus
            data["distMatrix"][destination][vehicleData["vehicleEnd"][vehicleIndex]], # the time it takes to go from the current location to the vehicle depot
            onboardPatients.copy() # should be empty
            )) # the last trip is to the vehicle depot
        
    return vehicleTrips


# -----------------------------------------------------------------------------
# ----------------------------------- Setup -----------------------------------
# -----------------------------------------------------------------------------

input_name = argv[1]
output_name = argv[2]

input_file = open(input_name, 'r')
input_mnz = open(input_name + ".mzn.json", 'w')
output_file = open(output_name, 'w')

data = load(input_file)

model = Model("./ptp.mzn")
solver = Solver.lookup("gecode")
instance = Instance(solver, model)


# -----------------------------------------------------------------------------
# ------------------------ Parse Input & Assign Values ------------------------
# -----------------------------------------------------------------------------
# JSON input format:
# {
#     "sameVehicleBackward": <bool>,
#     "maxWaitTime": <str>, # HHhMM
#     "places": [
#         {
#             "id": <int>,
#             "category": <int>
#         }
#     ],
#     "vehicles": [
#         {
#             "id": <int>,
#             "canTake": [<int>],
#             "start": <int>,
#             "end": <int>,
#             "capacity": <int>,
#             "availability": [<str>] # HHhMM:HHhMM
#         }
#     ],
#     "patients": [
#         {
#             "id": <int>,
#             "category": <int>,
#             "load": <int>,
#             "start": <int>,
#             "destination": <int>,
#             "end": <int>,
#             "rdvTime": <str>, # HHhMM
#             "rdvDuration": <str>, # HHhMM
#             "srvDuration": <str> # HHhMM
#         }
#     ]
# }

placesIndexToId = {index:place["id"] for index, place in enumerate(data["places"])}
patientsIndexToId = dict()

instance["sameVehicleBackward"] = data["sameVehicleBackward"]
instance["maxWaitTime"] = get_minutes(data["maxWaitTime"])

noPlaces = len(data["places"])
instance["noPlaces"] = noPlaces
instance["placeCategory"] = [get_place_category(place["category"]) for place in data["places"]]

noTrueVehicles = len(data["vehicles"])
vehicleAvailabilityLenghts = [len(vehicle["availability"]) for vehicle in data["vehicles"]]
noVehicles = max(vehicleAvailabilityLenghts)*noTrueVehicles
instance["noVehicles"] = noVehicles
vehiclesIndexToId = {index:-1 for index in range(noVehicles)}
vehiclesIdToIndexRange = {vehicle["id"]:(0,0) for vehicle in data["vehicles"]}

noCategories = len({cat for vehicle in data["vehicles"] for cat in vehicle["canTake"]})
instance["noCategories"] = noCategories

vehicleData = dict(
    vehicleCanTake = [[False]*noCategories]*noVehicles,
    vehicleStart = [0]*noVehicles,
    vehicleEnd = [0]*noVehicles,
    vehicleCapacity = [0]*noVehicles,
    vehicleAvailability = [[0,0]]*noVehicles,
)

nextIndex = 0

for vehicle in data["vehicles"]:
    commonId = vehicle["id"]
    commonCanTake = [True if i in vehicle["canTake"] else False for i in range(noCategories)]
    commonStart = vehicle["start"]
    commonEnd = vehicle["end"]
    commonCapacity = vehicle["capacity"]
    firstVehicleIndex = nextIndex
    for index, availability in enumerate(vehicle["availability"]):
        vehiclesIndexToId[nextIndex + index] = commonId
        vehicleData["vehicleCanTake"][nextIndex + index] = commonCanTake
        vehicleData["vehicleStart"][nextIndex + index] = commonStart
        vehicleData["vehicleEnd"][nextIndex + index] = commonEnd
        vehicleData["vehicleCapacity"][nextIndex + index] = commonCapacity
        vehicleData["vehicleAvailability"][nextIndex + index] = get_availability(availability)
    vehiclesIdToIndexRange[commonId] = (firstVehicleIndex, nextIndex+index)
    nextIndex += index + 1


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
    patientsIndexToId[index] = patient["id"]
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


# print("=============== DATA INPUT TO MINIZINC ===============")
# print("sameVehicleBackward:", data["sameVehicleBackward"])
# print("maxWaitTime:", get_minutes(data["maxWaitTime"]))
# print("noPlaces:", noPlaces)
# print("placeCategory:", [get_place_category(place["category"]) for place in data["places"]])
# print("noVehicles:", noVehicles)
# print("noCategories:", noCategories)
# print("vehicleCanTake:", vehicleData["vehicleCanTake"])
# print("vehicleStart:", vehicleData["vehicleStart"])
# print("vehicleEnd:", vehicleData["vehicleEnd"])
# print("vehicleCapacity:", vehicleData["vehicleCapacity"])
# print("vehicleAvailability:", vehicleData["vehicleAvailability"])
# print("noRequests:", noRequests)
# print("requestStart:", requestData["requestStart"])
# print("requestDestination:", requestData["requestDestination"])
# print("requestReturn:", requestData["requestReturn"])
# print("requestLoad:", requestData["requestLoad"])
# print("requestServiceStartTime:", requestData["requestServiceStartTime"])
# print("requestServiceDuration:", requestData["requestServiceDuration"])
# print("requestCategory:", requestData["requestCategory"])
# print("requestBoardingDuration:", requestData["requestBoardingDuration"])
# print("distMatrix:", data["distMatrix"])
dump(
    {
        "sameVehicleBackward": data["sameVehicleBackward"],
        "maxWaitTime": get_minutes(data["maxWaitTime"]),
        "noPlaces": noPlaces,
        "placeCategory": [get_place_category(place["category"]) for place in data["places"]],
        "noVehicles": noVehicles,
        "noCategories": noCategories,
        "vehicleCanTake": vehicleData["vehicleCanTake"],
        "vehicleStart": vehicleData["vehicleStart"],
        "vehicleEnd": vehicleData["vehicleEnd"],
        "vehicleCapacity": vehicleData["vehicleCapacity"],
        "vehicleAvailability": vehicleData["vehicleAvailability"],
        "noRequests": noRequests,
        "requestStart": requestData["requestStart"],
        "requestDestination": requestData["requestDestination"],
        "requestReturn": requestData["requestReturn"],
        "requestLoad": requestData["requestLoad"],
        "requestServiceStartTime": requestData["requestServiceStartTime"],
        "requestServiceDuration": requestData["requestServiceDuration"],
        "requestCategory": requestData["requestCategory"],
        "requestBoardingDuration": requestData["requestBoardingDuration"],
        "distMatrix": data["distMatrix"]
    },
    fp=input_mnz
)
# print("======================================================")

# -----------------------------------------------------------------------------
# --------------------------- Solve & Parse Output ----------------------------
# -----------------------------------------------------------------------------
# JSON output format:
# {
#     "requests": <int>,
#     "vehicles": [
#         {
#             "id": <int>,
#             "trips": [
#                 {
#                     "origin": <int>,
#                     "destination": <int>,
#                     "arrival": <str>, # HHhMM
#                     "patients": [<int>]
#                 }
#             ]
#         }
#     ]
# }


result = instance.solve()   

print(result)

vehicleTrips = get_trips_by_vehicle(result["activityStart"], result["activityEnd"], result["activityVehicle"])

dump(
    {
        "requests": result["objective"],
        "vehicles": [
            {
                "id": vehiclesIndexToId[i],
                "trips": [
                    {
                        "origin": placesIndexToId[trip[0]],
                        "destination": placesIndexToId[trip[1]],
                        "arrival": f"{trip[2]//60}h{trip[2]%60:02d}",
                        "patients": [patientsIndexToId[patient] for patient in trip[3]]
                    }
                    for trip in vehicleTrips[i]
                ]
            } for i in range(noTrueVehicles)
        ]
    },
    fp=output_file
)

