import ee
ee.Authenticate()
ee.Initialize(project="collisions-and-climate")

print("Connected!")
print(ee.String('Hello from the Earth Engine servers!').getInfo())