#!/usr/bin/awk -f
# takes files with YAML front matter and if they don't have years key but have date key - derives years from date. Writes processed file to the output.

BEGIN {  }
{ 
  if($1 == "date:") { 
    yearFromDate = substr($2, 2, 4)
  }
  if($1 == "years:") {
    yearsSpecified = 1 
    print "years already specified:", $2 > "/dev/stderr"
  }
  if($1 == "---" && yearFromDate && !yearsSpecified) {
    printf("years: ['%4d']\n", yearFromDate)
  }

  print $0 
}
END { }

