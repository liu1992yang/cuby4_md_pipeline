#!/bin/bash

module load anaconda3_4.3.1

PYTHON_FTYPE="$1" PYTHON_FUNCTIONAL="$2" PYTHON_BASISSET="$3" /gscratch/sw/anaconda-4.3.1/python3/bin/python3.6  - << END

import sys
import os
import subprocess

FTYPE = os.environ['PYTHON_FTYPE']
FUNCTIONAL = os.environ['PYTHON_FUNCTIONAL']
BASISSET = os.environ['PYTHON_BASISSET']
assert FTYPE and FUNCTIONAL and BASISSET, "python required variable empty\nUsage ./extract_opted_pm6.sh filetype functional basis-set"

def file_exist(fname):
  '''
  check if a path exists
  '''
  if not os.path.exists(fname):
    print(fname + ' does not exist')
    return False
  return True

def read_charge_multp(folder):
  if not file_exist(folder):
    return 
  flist = os.listdir(folder)
  inp = None
  for fn in flist:
    if fn.startswith('inp'):
      inp = fn
  if not inp:
    print('no original inp file found')
    return
  multipl = '1'
  with open(os.path.join(folder,inp)) as fin:
    for line in fin:
      curr_line = line.strip()
      if curr_line.startswith('charge'):
        charge = curr_line.split(':')[1].strip()
      if curr_line.startswith('multiplicity'):
        multipl = curr_line.split(':')[1].strip()
    return charge, multipl

def get_snap_folders():
  return sorted([d_name for d_name in os.listdir(os.getcwd()) if os.path.isdir(d_name) and 'snap' in d_name])


def get_opt_fname(folder):
  if not file_exist(folder):
    return 
  flist = os.listdir(folder)
  opt_fn = [i for i in flist if i.startswith('optimized')]
  if not opt_fn:
    print("{} not optimized".format(folder))
    return
  opt_fn = ''.join(opt_fn)
  return opt_fn 

def get_xyz_energy(folder, charge, multipl):
  opt_fn = get_opt_fname(folder)
  if not opt_fn:
    return 
  energy = None
  opt_xyz = []
  with open(os.path.join(folder,opt_fn)) as fin:
    for line in fin:
      if line.startswith('Energy'):
        energy = line.strip().split()[1]
        continue
      if not line.startswith('  '):
        continue
      if line.strip() == '':
        continue 
      opt_xyz.append(line)
  with open(os.path.join('dftsubs',folder + '.' + FTYPE), 'w') as fout:
    fout.write('''%mem=128gb
%nproc=28       
%Chk={0}.chk
#p opt {1}/{2}  scf=(xqc, tight)  pop=min     

Complex {3}

{4} {5}
'''.format(folder,FUNCTIONAL,BASISSET,folder,charge, multipl))
    fout.write(''.join(opt_xyz))
    fout.write('\n')
  return energy

def format_energy(folder,energy):
  if not energy:
    return 
  return '\t'.join([folder + '.' + FTYPE, energy])

def extract_all(folder_list):
  energy_content = []
  if not file_exist('dftsubs'):
    print('dir dftsubs not found!')
    sys.exit(1)
  for folder in folder_list:
    energy = get_xyz_energy(folder, charge, multipl)
    energy_content.append(format_energy(folder,energy))
  with open(os.path.join('dftsubs','pm6_energy_combine.txt'),'w') as fout:
    fout.write('\n'.join(line for line in energy_content if line))
    

if __name__ == '__main__':
  folder_list = get_snap_folders()
  if not folder_list:
    print('no snap folder found!')
    sys.exit(1)
  #only need to read charge, multiplicity once for all files
  charge, multipl = read_charge_multp(folder_list[0])
  print(charge, multipl)
  subprocess.call(['mkdir','dftsubs'])
  extract_all(folder_list)
  sys.exit()
END

if [[ $? = 0 ]]; then
  echo "extracted optimized geometries and energy info are in dftsubs folder"
  echo "please see 'pm6_energy_combine.txt' for energy profile"
else
  echo "failure:$?"
fi
