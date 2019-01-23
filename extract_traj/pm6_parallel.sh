#!/bin/bash
#SBATCH --job-name=pm6s
#SBATCH --nodes=1
#SBATCH --time=72:00:00
#SBATCH --mem=100Gb
#SBATCH --workdir=/gscratch/stf/yliu92/mono_md/demo_folder
#SBATCH --partition=ilahie
#SBATCH --account=ilahie

#module load parallel_sql
module load parallel-20170722
module load contrib/mopac16
source /usr/lusers/yliu92/.rvm/scripts/rvm


ldd /sw/contrib/cuby4/cuby4/classes/algebra/algebra_c.so > ldd.log
cat pm6_tasks | parallel -j 28

