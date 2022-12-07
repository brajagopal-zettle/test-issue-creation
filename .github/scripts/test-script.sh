#!/bin/bash

frontSearchstring='\\n\\n'
backSearchString='\\n\\n*'
a='This is a production release.\n<details>\n<summary>CHANGELOG (all commits)</summary>\n\n* 4c679f4 1670408794 Balaji Rajagopal 2022-12-07:11:26:34 - Changing the checkout version to v3\n* d1c3234 1670408695 Balaji Rajagopal 2022-12-07:11:24:55 - Fixing the reponame for issue\n* b42f733 1670408504 Balaji Rajagopal 2022-12-07:11:21:44 - Test workflow (#5)\n* 730b371 1670408294 Balaji Rajagopal 2022-12-07:11:18:14 - Test workflow (#3)\n\n</details>'
b=${a#*$backSearchString}
c=${b%$frontSearchstring*}
echo "$c"


#Define the string value
text="Welcome to LinuxHint"

# Set space as the delimiter
IFS='\\n*'

#Read the split words into an array based on space delimiter
read -a strarr <<< "$c"

#Count the total words
echo "There are ${#strarr[*]} words in the text."

# Print each value of the array by using the loop
for val in "${strarr[@]}";
do
  printf "$val\n"
done

