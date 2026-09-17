"""
Authenticates to Earth Engine and confirms the connection works.

- One-time/occasional sanity check, not part of the numbered pipeline.
- No data-handling decisions -- just an auth + connection test.
"""


import ee
ee.Authenticate()
ee.Initialize(project="collisions-and-climate")

print("Connected!")
print(ee.String('Hello from the Earth Engine servers!').getInfo())