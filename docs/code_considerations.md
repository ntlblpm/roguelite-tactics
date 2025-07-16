### Would be better to use composition over inheritance for player character scripts

playable characters (archer, pyromancer, swordsman) currently follow an inheritance structure, instead of composition. 
may be better and easier or even necessary to switch to composition down the line. this would involve creating and using components like StatsComponent (to manage hp/ap/mp), AbilityComponent, etc. Need to figure out what the common components are