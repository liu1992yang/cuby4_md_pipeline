#!/bin/bash
#SBATCH --job-name=mds
#SBATCH --nodes=1
#SBATCH --time=72:00:00
#SBATCH --mem=100Gb
#SBATCH --workdir=/gscratch/stf/yliu92/mono_md/pipline_folder
#SBATCH --partition=chem
#SBATCH --account=chem

module load parallel_sql
module load contrib/mopac16
source /usr/lusers/yliu92/.rvm/scripts/rvm

cat md_tasklist|psu --load

ldd /sw/contrib/cuby4/cuby4/classes/algebra/algebra_c.so > ldd.log

parallel_sql --sql -a parallel --exit-on-term -j 8
