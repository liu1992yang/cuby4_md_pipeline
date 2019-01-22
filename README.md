# cuby4_md_pipeline
a pipeline to work with gaussian readable initial structures for cuby4-mopac interfaced BOMD and downstream snapshot geometry optimization  
* (1)BOMD at desired temperature and maxcycles  
start with gaussview generated z-matrix geometry format (*.gjf or *.com), generate individual sub-dirs e.g. s0-H, with converted cuby4 readable format s0-H.xyz and anneal.yaml within the dir for every initial structure in current dir; then an `md_tasklist` as tasklist and `multiple_md.sh` for parallel submission (with parallel_sql customized for uw-hyak); also a `filelist` for future use  

** `usage gen_md_jobs.sh filetype max_md_cycle temperature(K)`  
filetype: `com` | `gjf`  
max_md_cycle(int): e.g. `20000` (fs)  
temperature(int): e.g. `410` (K)  

** requirement:  
*** (i) gaussview generated file must have correct(desired) charge and multiplicity and in z-matrix format split by white spaces  
*** (ii) must have input for max_md_cycle(int) and temperature(int)  
*** (iii) may need to manually change partition and run time in `multiple_md.sh`  
*** (iv) note: resulted *.xyz files has total atom number on 1st line, blank line on 2nd and atom, coordinate starting from 3rd line and no extra line  

* (2)extraction of snapshots (of some interval steps as your choice) from generated trajectories  


* (3)geometry optimization of these snapshots
* (4)extract optimized geometries as Gaussian/gaussview readable format (`.com` or `.gjf` of your choice) with extracted energies at current computation level, 
The output files are ready to use conformation sorting (see `geometry_clustering` repo)
