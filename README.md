# vcr
![](assets/vcr-photo.png)
a simple Voltage Collection Recall script for norns + grid + crow

## norns

![](assets/vcr-1.png)

#### keys
  1. alt
  2. navigate to previous voltage set
  3. navigate to next voltage set

#### encoders
  1. set voltage 1 for the current voltage set
  2. set voltage 2 for the current voltage set
  3. set voltage 3 for the current voltage set

holding alt will shift focus to a second set of parameters:

![](assets/vcr-2.png)

  1. **(+ alt)** set slew shape/style for the current voltage set
  2. **(+ alt)** set voltage 4 for the current voltage set
  3. **(+ alt)** set slew time for the current voltage set


## grid

![](assets/grid.png)

gotta re-write this before sharing the script.

## crow

crow outputs 1-4 will carry voltages 1-4 from your voltage sets.

-----------

## slew shapes/styles

* 'linear'
* 'sine'
* 'logarithmic'
* 'exponential'
* 'now': ignore slew time, go instantly to the destination then wait
* 'wait': wait at the current level, then go to the destination
* 'over': move toward the destination and overshoot, before landing
* 'under': move away from the destination, then smoothly ramp up
* 'rebound': emulate a bouncing ball toward the destination

