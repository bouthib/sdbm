for FICHIER in $(ls -1 *.sql)
do
   mv $FICHIER $FICHIER.old
   dos2unix $FICHIER.old
   cat ../_licence.txt > $FICHIER
   cat $FICHIER.old >> $FICHIER
done
