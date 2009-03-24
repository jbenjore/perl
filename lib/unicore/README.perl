The *.txt files were copied from

	http://www.unicode.org/Public/5.1.0/ucd

as of Unicode 5.1.0 (March 2008).

The big file, Unihan.txt (28 MB, 5.8 MB zip) was not included due to space
considerations.  Also NOT included were any *.html files and *Test.txt files.
The files in subdirectories of lib/unicore were moved up to lib/unicore.

To be 8.3 filesystem friendly, the names of some of the input files in
lib/unicore have been changed from the values that are in the Unicode DB:

mv PropertyValueAliases.txt PropValueAliases.txt
mv NamedSequencesProv.txt NamedSqProv.txt
mv DerivedAge.txt DAge.txt
mv DerivedBidiClass.txt DBidiClass.txt
mv DerivedBinaryProperties.txt DBinaryProperties.txt
mv DerivedCombiningClass.txt DCombiningClass.txt
mv DerivedCoreProperties.txt DCoreProperties.txt
mv DerivedDecompositionType.txt DDecompositionType.txt
mv DerivedEastAsianWidth.txt DEastAsianWidth.txt
mv DerivedGeneralCategory.txt DGeneralCategory.txt
mv DerivedJoiningGroup.txt DJoinGroup.txt
mv DerivedJoiningType.txt DJoinType.txt
mv DerivedLineBreak.txt DLineBreak.txt
mv DerivedNormalizationProps.txt DNormalizationProps.txt
mv DerivedNumericType.txt DNumType.txt
mv DerivedNumericValues.txt DNumValues.txt

NOTE: If you modify the input file set you should also run
 
    mktables -makelist
    
which will recreate the mktables.lst file which is used to speed up
the build process.    

FOR PUMPKINS

The files are inter-related.  If you take the latest UnicodeData.txt, for example,
but leave the older versions of other files, there can be subtle problems.

There are two properties whose composition isn't (as of Version 5.1) given by
Unicode.  These are Cased and Case_Ignorable (which perl publishes both
prefixed by an underscore, as it doesn't appear that Unicode wants to make them
public, but both are needed for changing case).  It should be verified that the
definitions of these haven't changed with each new Unicode release.

The *.pl files are generated from the *.txt files by the mktables script,
more recently done during the Perl build process, but if you want to try
the old manual way:
	
	cd lib/unicore
	cp .../UnicodeOriginal/*.txt .
	rm NormalizationTest.txt Unihan.txt D*.txt
	p4 edit Properties *.pl */*.pl
	perl ./mktables
	p4 revert -a
	cd ../..
	perl Porting/manicheck

You need to update version by hand

	p4 edit version
	...
	
If any new (or deleted, unlikely but not impossible) *.pl files are indicated:

	cd lib/unicore
	p4 add ...
	p4 delete ...
	cd ../...
	p4 edit MANIFEST
	...

And finally:

	p4 submit

-- 
jhi@iki.fi; updated by nick@ccl4.org
