#/bin/bash
. ~/.storj.
IFS=$'\n'
curDate=`date -u +%s`

for dir in *
do
	bucket=`storj list-buckets | grep "Name: $dir"`
	bucketId=`echo $bucket | awk '{ print $2}'`
	if [ "$bucketId" ]
	then
		dateCreate=`echo $bucket | awk '{print $6}'`
		if [[ $(($curDate - `date -d $dateCreate +%s`)) -gt $((60*60*24*90)) ]]
		then
			eval 'storj remove-bucket $bucketId'
			unset bucketId
		fi
	fi
	if [ -z "$bucketId" ]
	then
#		echo "$dir not found. Will create"
		bucketId=`storj add-bucket "$dir" | awk '{ print $2}'`
	fi

	bucketfiles=`storj list-files "$bucketId"`

	for file in $(find $dir -type f)
	do
		echo $file
		IFS=
	        bucketFile=`echo $bucketfiles | grep "Name: $(basename $file)"`
		IFS=$'\n'
	        bucketFileId=`echo $bucketFile | awk '{ print $2}'`
	        bucketFileCreateDate=`echo $bucketFile | awk '{ print $11}'`

		if [ "$bucketFileId" ]
		then
			countMirrors=`storj list-mirrors "$bucketId" "$bucketFileId" | grep -ic "nodeId"`
			if [[ $countMirrors -lt 5 || $(($curDate - `date -d $bucketFileCreateDate +%s`)) -gt $((60*60*24*90)) ]]
			then
				echo "Mirrors: $countMirrors date $(date -d $bucketFileCreateDate -Ins)"
				eval 'storj remove-file $bucketId $bucketFileId'
				unset countMirrors
				unset bucketFileId
			fi
		fi
		if [ -z "$bucketFileId" ]
		then
#			echo "File not found. Will upload"
       			eval 'storj upload-file $bucketId "$file"'
		fi
	done
done
