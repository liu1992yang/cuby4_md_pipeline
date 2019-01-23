# cuby4_md_pipeline
a pipeline to work with gaussian readable initial structures for cuby4-mopac interfaced BOMD and downstream snapshot geometry optimization 

### require to run on Hyak with `srun` and have `parallel_sql` installed  
get an interactive session on mox.hyak by using  
`srun -p stf-int -A stf --time=2:00:00 --mem=10G --pty /bin/bash`

## (1)BOMD at desired temperature and maxcycles  
start with gaussview generated z-matrix geometry format (*.gjf* or *.com*), generate individual sub-dirs e.g. s0-H, with converted cuby4 readable format s0-H.xyz and anneal.yaml within the dir for every initial structure in current dir; then an `md_tasklist` as tasklist and `multiple_md.sh` for parallel submission (with parallel_sql customized for uw-hyak); also a `filelist` for future use  

### `usage ./gen_md_jobs.sh filetype max_md_cycle temperature(K)`  
filetype: `com` | `gjf`  
max_md_cycle(int): e.g. `20000` (fs)  
temperature(int): e.g. `410` (K)  

then `sbatch multiple_md.sh` for submission

### requirement:  
* (i) gaussview generated file must have correct(desired) charge and multiplicity and in z-matrix format split by white spaces  
* (ii) must have input for max_md_cycle(int) and temperature(int)  
* (iii) may need to manually change partition and run time in `multiple_md.sh`  
* (iv) note: suggested original filename(e.g. COMPLEX.gjf) not including underscore "**_**"   
resulted COMPLEX.xyz files has total atom number on 1st line, blank line on 2nd and `atom, coordinate(x y z)` starting from 3rd line and no extra line  

## (2)extraction of snapshots (of some interval steps as your choice) from generated trajectories  
A memory efficient way to split long file  
With `filelist` generated from previous step, and `trajecotry*.xyz` files generated by cuby4 in individual dir, extract one snapshot every *interval* steps and save the the z-matrix format coordinates into \*.xzy file, cuby4 required inp*.yaml, generate individual dir (see y7-H_410K_snap_4 as example) storing corresponding `.xyz` and `inp` files, and `pm6_tasks` as tasklist and `pm6_parallel.sh` as sbatch  parallel submission script
parallel_sql is very similar to standard GNU parallel but instead of getting tasks from STDIN of a file, instances of parallel-sql retrieve unique tasks out of an SQL database as needed until all the tasks are complete; This sometimes fails with thousands of jobs with cuby4, common error as "no child process" even specified absolute path of input.  
An alternative way to run parallel is to use GNU parallel, which is updated in the `pm6_parallel.sh`

### `usage: ./traj_process.sh filelist interval_steps`
filelist:  the `filelist` generated from previous step  
interval_steps: e.g. `100` (fs steps, every 100 fs extract 1 snapshot)  
### requirement:  
* (i) `filelist` content exist no extension or whitespace
* (ii) `trajecotry*.xyz` exists has file name starts with "trajectory"
* (iii) `anneal*.yaml` exists in original dir
* (iv) may need to manually change partition and run time in `pm6_parallel.sh`
* (v) note: resulted dir has **COMPLEXNAME_TEMPERATURE_snap_NUMBER** style format that has **3** underscores, suggested COMPLEXNAME not including underscores

## (3)geometry optimization of these snapshots
`sbatch pm6_parallel.sh` for parallel pm6 optimization submission


## (4)extract optimized geometries as Gaussian/gaussview readable format (`.com` or `.gjf` of your choice) with extracted energies at current computation level  
After pm6 optimizations, extract optimized geometries from "\*snap\*" dirs and energy at current compuation level, format the coordinates in gaussian/gaussview readable format (.com or .gjf, you name it) and save the energy in a `pm6_energy_combine.txt` file in a directory called `dftsubs`  
### `usage ./extract_opted_pm6.sh filetype functional basis-set`  
filetype: `com` | `gjf`  
functional: e.g. `wb97xd`  
basis-set: e.g. `6-31g\(d,p\)` **(need to escape parentheses "(" and ")")**  


The output files are ready to use conformation sorting (see `geometry_clustering` repo)
### requirement:  
* (i) file in original format
* (ii) basis-set in correct format
* (iii) non-optimized snapshots will have no entry in energy file, will print out to console but will not raise error
