Beyblade simulator using godot

PHYSICS 
Beyblades represented as RigidBody3D nodes but handle their own spin and collision
Every physics frame:
  - Desired spin value tracked and decreased gradually
  - Drag and friction applied to the beyblade
  - Gyroscopic force simulated by comparing the normal from the floor and beyblade's up direction and applying a force to rotate the beyblade towards the floor normal
  - A small random wobble force is applied to the beyblade
  - A propulsion force is applied in the direction of the tilt to give the erratic speedy movement of a beyblade
    
On collision:
  - The collision direction is checked
  - The relative velocity of the beyblades is calculated
  - Impact force calculated using relative velocities, weights and a collision constant
  - Knockback is applied to the other beyblade on the following frame
  - Particle and audio effects are activated 
