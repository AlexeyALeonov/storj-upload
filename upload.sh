#/bin/bash
. ~/.storj.
IFS=$'\n'

for dir in *
do
	bucketId=`storj list-buckets | grep "Name: $dir" | awk '{ print $2}'`
	if [ -z "$bucketId" ]
	then
#		echo "$dir not found. Will create"
		bucketId=`storj add-bucket "$dir" | awk '{ print $2}'`
	fi

	bucketfiles=`storj list-files "$bucketId"`

	for file in $(find $dir -type f)
	do
		echo $file
	        bucketFileId=`echo $bucketfiles | grep "Name: $(basename $file)" | awk '{ print $2}'`

		if [ -z "$bucketFileId" ]
		then
#			echo "File not found. Will upload"
       			eval 'storj upload-file $bucketId "$file"'
		fi
	done
done
