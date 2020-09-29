#!/usr/bin/env bash
set -Eeuo pipefail

USERNAME=${1:-test}
PASSWORD=${2:-test}

searchConceptChildren1="/"
resultSearchConceptChildren1="PATH	TYPE
/CLINICAL_NON_SENSITIVE/medco/clinical/nonsensitive/	concept_container
/CLINICAL_SENSITIVE/medco/clinical/sensitive/	concept_container
/GENOMIC/medco/genomic/	concept_container"

searchConceptChildren2="/E2ETEST/e2etest/"
resultSearchConceptChildren2="PATH	TYPE
/E2ETEST/e2etest/1/	concept
/E2ETEST/e2etest/2/	concept
/E2ETEST/e2etest/3/	concept
/E2ETEST/modifiers/	modifier_folder"

searchModifierChildren="/E2ETEST/modifiers/ /e2etest/% /E2ETEST/e2etest/1/"
resultSearchModifierChildren="PATH	TYPE
/E2ETEST/modifiers/1/	modifier"

query1="1 AND 2"
resultQuery1="$(printf -- "count\n8\n8\n8")"
query2="6 OR 16 AND 8"
resultQuery2="$(printf -- "count\n1\n1\n1")"
query3="5 AND 10 AND 15"
resultQuery3="$(printf -- "count\n3\n3\n3")"
query4="4 OR 11 OR 17"
resultQuery4="$(printf -- "count\n5\n5\n5")"
query5="3 OR 6 AND 9 AND 12 OR 15"
resultQuery5="$(printf -- "count\n2\n2\n2")"

variantNameGetValuesValue="5238"
variantNameGetValuesResult="$(printf "16:75238144:C>C\n6:52380882:G>G")"
proteinChangeGetValuesValue="g32"
proteinChangeGetValuesResult="$(printf "G325R\nG32E")"
proteinChangeGetValuesValue2="7cfs*"
proteinChangeGetValuesResult2="S137Cfs*28"
hugoGeneSymbolGetValuesValue="tr5"
hugoGeneSymbolGetValuesResult="HTR5A"

variantNameGetVariantsValue="16:75238144:C>C"
variantNameGetVariantsResult="-4530899676219565056"
proteinChangeGetVariantsValue="G325R"
proteinChangeGetVariantsResult="-2429151887266669568"
hugoGeneSymbolGetVariantsValue="HTR5A"
hugoGeneSymbolGetVariantsResult1="$(printf -- "-7039476204566471680\n-7039476580443220992\n-7039476780159200256")"
hugoGeneSymbolGetVariantsResult2="$(printf -- "-7039476204566471680\n-7039476580443220992")"
hugoGeneSymbolGetVariantsResult3="-7039476780159200256"

test1 () {
  docker-compose -f docker-compose.tools.yml run medco-cli-client --user $USERNAME --password $PASSWORD --o /results/result.csv $1 $2
  result="$(cat ../result.csv)"
  if [ "${result}" != "${3}" ];
  then
  echo "$1 $2: test failed"
  echo "result: ${result}" && echo "expected result: ${3}"
  exit 1
  fi
}

test2 () {
  docker-compose -f docker-compose.tools.yml run medco-cli-client --user $USERNAME --password $PASSWORD --o /results/result.csv $1 $2
  result="$(awk -F "\"*,\"*" '{print $2}' ../result.csv)"
  if [ "${result}" != "${3}" ];
  then
  echo "$1 $2: test failed"
  echo "result: ${result}" && echo "expected result: ${3}"
  exit 1
  fi
}

test3 () {
  result="$(docker-compose -f docker-compose.tools.yml run -e LOG_LEVEL=1 -e CONN_TIMEOUT=10m medco-cli-client --user $USERNAME --password $PASSWORD $1 $2 | sed 's/.$//')"
  if [ "${result}" != "${3}" ];
  then
  echo "$1 $2: test failed"
  echo "result: ${result}" && echo "expected result: ${3}"
  exit 1
  fi
}

echo "Testing concept-children..."

test1 "concept-children" "${searchConceptChildren1}" "${resultSearchConceptChildren1}"
test1 "concept-children" "${searchConceptChildren2}" "${resultSearchConceptChildren2}"

echo "Testing modifier-children..."

test1 "modifier-children" "${searchModifierChildren}" "${resultSearchModifierChildren}"

echo "Testing query..."

test2 "query patient_list" "${query1}" "${resultQuery1}"
test2 "query patient_list" "${query2}" "${resultQuery2}"
test2 "query patient_list" "${query3}" "${resultQuery3}"
test2 "query patient_list" "${query4}" "${resultQuery4}"
test2 "query patient_list" "${query5}" "${resultQuery5}"

echo "Testing ga-get-values..."

test3 "ga-get-values variant_name" "${variantNameGetValuesValue}" "${variantNameGetValuesResult}"
test3 "ga-get-values protein_change" "${proteinChangeGetValuesValue}" "${proteinChangeGetValuesResult}"
test3 "ga-get-values protein_change" "${proteinChangeGetValuesValue2}" "${proteinChangeGetValuesResult2}"
test3 "ga-get-values hugo_gene_symbol" "${hugoGeneSymbolGetValuesValue}" "${hugoGeneSymbolGetValuesResult}"

echo "Testing ga-get-variant..."

test3 "ga-get-variant variant_name" "${variantNameGetVariantsValue}" "${variantNameGetVariantsResult}"
test3 "ga-get-variant protein_change" "${proteinChangeGetVariantsValue}" "${proteinChangeGetVariantsResult}"
test3 "ga-get-variant hugo_gene_symbol" "${hugoGeneSymbolGetVariantsValue}" "${hugoGeneSymbolGetVariantsResult1}"
test3 "ga-get-variant --z "heterozygous" hugo_gene_symbol" "${hugoGeneSymbolGetVariantsValue}" "${hugoGeneSymbolGetVariantsResult2}"
test3 "ga-get-variant --z "unknown" hugo_gene_symbol" "${hugoGeneSymbolGetVariantsValue}" "${hugoGeneSymbolGetVariantsResult3}"
test3 "ga-get-variant --z "heterozygous\|homozygous" hugo_gene_symbol" "${hugoGeneSymbolGetVariantsValue}" "${hugoGeneSymbolGetVariantsResult2}"
test3 "ga-get-variant --z "heterozygous\|unknown" hugo_gene_symbol" "${hugoGeneSymbolGetVariantsValue}" "${hugoGeneSymbolGetVariantsResult1}"
test3 "ga-get-variant --z "homozygous\|unknown" hugo_gene_symbol" "${hugoGeneSymbolGetVariantsValue}" "${hugoGeneSymbolGetVariantsResult3}"
test3 "ga-get-variant --z "heterozygous\|homozygous\|unknown" hugo_gene_symbol" "${hugoGeneSymbolGetVariantsValue}" "${hugoGeneSymbolGetVariantsResult1}"

echo "E2E test succesful!"
exit 0