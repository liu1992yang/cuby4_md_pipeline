# cuby4_md_pipeline
a pipeline to work with gaussian readable initial structures for cuby4-mopac interfaced 
* (1)BOMD at desired temperature and maxcycles, 
* (2)extraction of snapshots (of some interval steps as your choice) from generated trajectories, 
* (3)geometry optimization of these snapshots and 
* (4)extract optimized geometries as Gaussian/gaussview readable format (`.com` or `.gjf` of your choice) with extracted energies at current computation level, 
The output files are ready to use conformation sorting (see `geometry_clustering` repo)
