#!/bin/bash

FILE_TYPE=$1
MAX_CYCLE=$2
TEMPERATURE=$3
module load anaconda3_4.3.1

PYTHON_FILE="$FILE_TYPE" PYTHON_CYCLE="$MAX_CYCLE" PYTHON_TEMP="$TEMPERATURE" /gscratch/sw/anaconda-4.3.1/python3/bin/python3.6  - << END

import sys
import os
import subprocess

FILETYPE = os.environ['PYTHON_FILE']
MAXCYCLE = os.environ['PYTHON_CYCLE']
TEMP = os.environ['PYTHON_TEMP']
assert FILETYPE and MAXCYCLE and TEMP, "python required environment variable empty\nUsage ./gen_task_md.sh filetype max_md_cycle temperature(K)"


def get_list():
  listofFiles = []
  try:
    for entry in os.listdir(os.getcwd()):
      #print(entry)
      if entry.endswith(FILETYPE):
        listofFiles.append(entry)
    return listofFiles

  except FileNotFoundError:
    print(FILETYPE+"NOT FOUND IN "+os.getcwd())
    sys.exit(1)


#need to read charge multiplicity
def convert_file(fname):
  '''
  input type str
  rtype tuple
  '''
  fn_out = fname.split('.')[0]+'.xyz'
  content=[]
  with open(fname) as fin:
    for line in fin:
      stripped_line = line.strip()
      if stripped_line.startswith('%') or stripped_line.startswith('#'):
        continue
      if stripped_line == '':
        continue
      arr = stripped_line.split()
      if len(arr) == 4:
        content.append(arr)
      if len(arr) == 2 and len(arr[1]) == 1:
        try:
          multiplicity = int(arr[1])
          charge = int(arr[0])
        except ValueError:
          print("Can not find charge/multiplicity")
          sys.exit()
  atom_num = len(content)
  with open(fn_out, 'w') as fout:
    fout.write(str(atom_num)+'\n')
    fout.write('\n')
    fout.write('\n'.join('\t'.join(item for item in line) for line in content))
  return charge, multiplicity

#NEED TO ADD MORE FLEXIBILITY
def write_yaml(folder, charge, multiplicity):
  with open(os.path.join(folder,'anneal.yaml'), 'w') as fout:
    fout.write('''\
job: dynamics
geometry: {0}.xyz
maxcycles: {1}
charge: {2}
multiplicity: {3}
timestep: 0.001
interface: mopac
mopac_precise: yes
mopac_peptide_bond_fix: yes
method: pm6
modifiers: dispersion3, h_bonds4
modifier_h_bonds4:
  h_bonds4_scale_charged: no
  h_bonds4_extra_scaling: {{}}
init_temp: {4}
thermostat: berendsen
thermostat_tc: 0.05
temperature: {4}
'''.format(folder,str(MAXCYCLE),str(charge),str(multiplicity), str(TEMP)))
    if multiplicity != 1:
      fout.write("spin_restricted: uhf")
      fout.write("scf_cycles: 1000")

def prep_file_md(fname,charge, multiplicity):
  folder = fname.split('.')[0]
  fxyz = folder + '.xyz'
  subprocess.call(['mkdir',folder])
  subprocess.call(['mv',fxyz, folder])
  write_yaml(folder, charge, multiplicity)

def write_sbatch(files):
  with open('multiple_md.sh','w') as batch:
    batch.write('''\
#!/bin/bash
#SBATCH --job-name=mds
#SBATCH --nodes=1
#SBATCH --time=72:00:00
#SBATCH --mem=100Gb
#SBATCH --workdir={0}
#SBATCH --partition=chem
#SBATCH --account=chem

module load parallel_sql
module load contrib/mopac16
source {1}/.rvm/scripts/rvm

cat md_tasklist|psu --load

ldd /sw/contrib/cuby4/cuby4/classes/algebra/algebra_c.so > ldd.log

parallel_sql --sql -a parallel --exit-on-term -j {2}
'''.format(os.getcwd(),os.environ['HOME'],str(len(files))))

def write_tasklist(files):
   with open('md_tasklist','w') as tasklist:
     tasklist.write('\n'.join('cd {}; cuby4 anneal.yaml &>LOG'.format(os.getcwd()+'/'+fname.split('.')[0]) for fname in files))


if __name__ == '__main__':
  
  #print(os.environ)
  print(FILETYPE)
  files = get_list()
  
  for fname in files:
    charge, multiplicity = convert_file(fname)
    prep_file_md(fname, charge, multiplicity)
    
  write_tasklist(files)
  write_sbatch(files)  


  #also writes a filelist 
  print("write out a 'filelist'")
  with open('filelist', 'w') as flist:
    flist.write('\n'.join(list(map(lambda x: x.split('.')[0],files))))
  


END
if [[ $? = 0 ]]; then
  echo "Please keep 'filelist' for future use"
  echo "Please run sbatch multiple_md.sh to submit for parallel md"
  echo "change partition name and runtime if needed"
else
  echo "failure:$?"
fi

