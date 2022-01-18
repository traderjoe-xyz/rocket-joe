contractPath=${1}
project=${2}
contract=`echo ${1} | perl -0777 -pe 's/.*\///g' | awk -F'.' '{print $1}'`
echo $contractPath
echo $contract
set -x
certoraRun ${contractPath} \
  --verify ${contract}:specs/sanity.spec \
  --optimistic_loop \
  --settings -t=300 \
  --cloud --msg "${project} ${contract} Sanity with optimistic loops"
