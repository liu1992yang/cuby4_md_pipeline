#!/bin/bash
module load anaconda3_4.3.1

PYTHON_FILELIST="$1" PYTHON_INTERVAL="$2" /gscratch/sw/anaconda-4.3.1/python3/bin/python3.6  - << END

import os, subprocess, sys
import functools, itertools

FILELIST= os.environ['PYTHON_FILELIST']
INTERVAL = os.environ['PYTHON_INTERVAL']
assert FILELIST and INTERVAL,'usage: traj_process.sh filelist interval_steps'


def get_prefix(filelist):
  flist = []
  try:
    with open(filelist) as fin:
      for line in fin:
        if not line.strip():
          continue
        flist.append(line.strip())
    return flist
  except OSError:
    print(filelist+ 'not found!')
    sys.exit(1)

def file_exist(fname):
  '''
  check if a path exists
  '''
  if not os.path.exists(fname):
    print(fname + ' does not exist')
    return False
  return True

def format_tasklist(tasklist):
  path = os.getcwd()
  if not tasklist:
    return #return None type if tasklist is empty
  return map(lambda x : 'cd {}; cuby4 inp.yaml&>LOG'.format(os.path.join(path,x)),tasklist)

def charge_multp_temp(prefix,anneal):
  #by default, if not found specified in the anneal
  '''
  rtype: charge: str(int)
  rtype: multipl: str(int)
  rtype: temp: str(int)
  '''
  multipl = '1'
  with open(os.path.join(prefix,anneal)) as fin:
    for line in fin:
      curr_line = line.strip()
      if line.startswith('charge'):
        charge = line.split(':')[1].strip()
        continue
      if line.startswith('temperature'):
        temp = line.split(':')[1].strip()
        continue
      if line.startswith('multiplicity'):
        multipl = line.split(':')[1].strip()
        continue
    return charge, multipl, temp


def split_traj(prefix,traj,temp,interval_steps, charge, multp):
  """
  interval_steps: int, others: str
  """ 
  with open(os.path.join(prefix,traj), 'r') as fin:
    counter = 1
    l1 = fin.readline().strip()
    assert l1, "empty 1st line"     
    atom_number = int(l1) 
    print(atom_number)
    current_snap = list(itertools.islice(fin,1 , atom_number+1)) 
    #the original 1st line has been read, so skip current 1st line
    skip = (atom_number+2)*(interval_steps-1)+2
    tasklist = []
    while fin:
      if not current_snap:
        break
      sub_folder = '{}_{}K_snap_{}'.format(prefix, temp, str(counter))
      #(1)mkdir of new folder
      subprocess.run(['mkdir',sub_folder])
      #(2)save geom to prefix_temp_snap_n.xyz
      write_sub(current_snap, atom_number, sub_folder)
      #(3)write inp.yaml
      write_yaml(sub_folder, charge, multp)
      #(4)add one task to tasklist
      tasklist.append(sub_folder)
      counter +=1
      current_snap = list(itertools.islice(fin,skip,skip+atom_number))
  return tasklist

def write_sub(snap, atom_num, sub_folder):
  content = map(lambda x: x.strip().split()[:4], snap)
  if not file_exist(sub_folder):
    print(sub_folder + 'has not been made yet')
    return #return nonetype
  with open(os.path.join(sub_folder, sub_folder +'.xyz'),'w') as fout:
    fout.write(str(atom_num)+'\n'+'\n')
    fout.write('\n'.join('\t'.join(elem for elem in line) for line in content))

def write_yaml(sub_folder, charge, multipl): 
  if not file_exist(sub_folder):
    return
  with open(os.path.join(sub_folder,'inp.yaml'),'w') as fout:
    fout.write('''job: optimize
geometry: {0}
charge: {1}
multiplicity: {2}
maxcycles: 2000
print: timing
interface: mopac
mopac_precise: yes
mopac_peptide_bond_fix: yes
method: pm6
modifiers: dispersion3, h_bonds4
modifier_h_bonds4:
  h_bonds4_scale_charged: no
  h_bonds4_extra_scaling: {{}}
'''.format(sub_folder + '.xyz',charge, multipl))


def process_one_traj(prefix, interval_steps):
  """
  interval_steps: int
  """
  #check if prefix directory exist
  if not file_exist(prefix):
    return #nonetype
  origin_flist = os.listdir(prefix)
  anneal, traj = None, None #initial nonetype
  for fn in origin_flist:
    if fn.startswith('anneal'):
      anneal = fn
    if fn.startswith('trajectory'):
      traj = fn
  if not anneal or not traj:
    print('no anneal or traj file found for {}'.format(prefix))
    return 
  #get charge mulplicity and  temperature
  charge, multp, temp = charge_multp_temp(prefix, anneal)
  #read traj, split up and write subfiles, return tasks for final tasks write out
  return split_traj(prefix, traj, temp, interval_steps, charge, multp)


def write_sbatch(task_number):
  with open('pm6_parallel.sh', 'w') as fout:
    fout.write('''#!/bin/bash
#SBATCH --job-name=pm6s
#SBATCH --nodes=1
#SBATCH --time=72:00:00
#SBATCH --mem=100Gb
#SBATCH --workdir={}
#SBATCH --partition=ilahie
#SBATCH --account=ilahie

#module load parallel_sql
module load parallel-20170722
module load contrib/mopac16
source {}/.rvm/scripts/rvm


ldd /sw/contrib/cuby4/cuby4/classes/algebra/algebra_c.so > ldd.log
cat pm6_tasks | parallel -j 28

'''.format(os.getcwd(),os.environ['HOME']))

if __name__ == '__main__':
  file_list = FILELIST
  interval = int(INTERVAL)
  prefix_list = get_prefix(file_list)
  print(prefix_list)
  all_tasks = list(map(functools.partial(process_one_traj, interval_steps = interval),prefix_list))
  task_number = sum(len(i) for i in all_tasks if i is not None)
  with open('pm6_tasks','w') as fout:
    fout.write('\n'.join('\n'.join(format_tasklist(i)) for i in all_tasks if i is not None))
  write_sbatch(task_number)
  sys.exit()

END
if [[ $? = 0 ]]; then
  echo "Please run sbatch pm6_parallel.sh for parallel pm6 optimization"
  echo "change partition name and run time if needed"
  echo "tasklist is stored in 'pm6_tasks'"
else
  echo "failure:$?"
fi
