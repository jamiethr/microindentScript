// an ImageJ script to help automate the data collection of cell microindentation experiments
// written by Jamie Thorup
// Last updated: 6/30/20, with new comments added 12/2/20

/* Current bugs (last updated: 6/30/20):
 *  
 *  	- actual, potential bug: the processed image doesn't close when the macro is set to loop?
 *  
 *		- KEEP IN-MIND THAT VERSIONS OF FIJI NEWER THAN V1.52v HAVE A BUG THAT BREAKS THE OVERLAY OPTIONS MENU
 *		- EVERY OPERATION WITH THE conversion VAR AFTER LINE 214 NEEDS PARENTHESES on both variables WHAT GIVES
 *		
 *		- it doesn't close the processed image after?
 *		
 *		- we also are getting the following exception:
 *		java.lang.RuntimeException: Unable to set Pixel format on Canvas
				at sun.awt.windows.WToolkit.eventLoop(Native Method)
				at sun.awt.windows.WToolkit.run(WToolkit.java:312)
				at java.lang.Thread.run(Thread.java:748)
		
		for some reason

 * 		  
 * TO DO (Last updated: 6/25/20):
 * 
 * 		- find an easy way for people to run this macro haha
 * 
 *		- add the outline mechanism to collect the ROI as an image.
 *				find a less anti-aliased way to saving the ROI on black image?
 * 				
 */

//doWand(723, 623); purple
//doWand(700, 693); green
//doWand(784, 663); red

// the code in the lines 39 - 44 are called script parameters:
// https://imagej.net/Script_parameters

#@ File(label="Output directory", description="Select the output directory", style="directory") outputDir
// File(label="Input directory (for WIP Loop)", description="Select the input directory (for WIP Loop)", style="directory") inputDir
#@ Integer(label = "Number of measurments to take", min = 1, value = 3) sampleNum
#@ boolean(label = "Append results to past table?") usePRefine
#@ boolean(label = "Print raw data table(s)?") printRaw
#@ boolean(label = "Put output files into separated folders?") oneFolder

SNAPSHOT = 350; 	// constant value; sets the size of the selection used to create the ROI as an image.
doAngle = false;	// this disables the measurement of the tip angle thing

// replaces escape characters to fix directory string
outputDir = replace(outputDir, "\\\\", "\\\\\\\\");
print("User-selected output directory: " + outputDir);


if(usePRefine){
	pRefine = File.openDialog("Select the table to ammend:");	// get the file for the past refined table
	pRefineDir = File.getParent(pRefine);						// get the directory for later.
	pRefineName = File.getName(pRefine);						// get the name of the file to save to.
}

doLoop = true;
while(doLoop){		// main loop. Repeats measuring steps and feeds user new images

	// allow user to set the looping option
	Dialog.create("Loop Macro");
	Dialog.addCheckbox("Loop the macro?", true);
	Dialog.addMessage("To exit the macro, select 'Cancel'.");
	Dialog.show();
	doLoop = Dialog.getCheckbox();

	// get our unindented image's info
	firstImage = File.openDialog("Select an unindented photo:");
	imageDir = File.getParent(firstImage);

	// open the first image and have the user outline the cell
	open(firstImage);
	setTool("polygon");
	waitForUser("Outline the cell to be indented, then select 'OK'.");
	
	// measure the cell area
	run("Measure");
	indexOffset = 1;					// this variable will keep indexing for the data table on-track
	selectWindow("Results");
	cellArea = Table.get("Area", 0);	// collects area for later use in refined table
	
	roiIndex = -1;						// controls indexing for the Results table
	
	if( selectionType() != -1){			// if-statement ensures a selection has been made
		run("ROI Manager...");
		roiManager("Add");
		roiIndex++;
		roiManager("Select", 0); 		// selects the ROI at the top of the ROI list
		
		cellName = "cell00";			// opens dialog box to collect cell name
		width = 512; height = 512;
		Dialog.create("Cell Number");
		Dialog.addString("Title:", cellName);
		Dialog.show();
		cellName = Dialog.getString();
	
		if(!oneFolder){					// if user wants one folder to store all outputs
			cellFilesOutputDir = outputDir;
		} else{
			// make a new folder to store .ROI's, and .CSV data files
			cellFilesOutputDir = outputDir + File.separator + cellName + " Data";
			File.makeDirectory(cellFilesOutputDir);
		}
		roiManager("Rename", cellName);		// actually renames the ROI
	
		// saves the ROI of the cell outline.
		if(roiManager("index") != -1){		// if there is an ROI selected.
			roiManager("Select", 0);		// RECALL: index 0 will always be the top of the manager
			saveAs("Selection", cellFilesOutputDir + File.separator + cellName + ".roi");
			print("Saved roi thingy to: " + cellFilesOutputDir);
		} else {
			exit("The selection could not be saved. Exiting the macro...");
		}

		// have the user measure lengths, widths of the cell
		setTool("line");
	
		print("Beginning length measuring loop...");
		measureLoop(indexOffset, "Length", sampleNum);
		// get the mean of means for the width lengths
		meanLength = getAverage(indexOffset, sampleNum);
		indexOffset += sampleNum;	// increment indexOffset to put the next data in the right rows.
	
		print("Beginning width measuring loop...");
		measureLoop(indexOffset, "Width", sampleNum);
		meanWidth = getAverage(indexOffset, sampleNum);
		indexOffset += sampleNum;
	
		// running the labeling here instead of right after it measures cell area to fix weird bug
		print("Labeling Cell Area on Results Table...");
		setResult("Label", 0, "Cell Area");		// label as "cell area" in data table
		updateResults();

 		// saving ROI as image:
 		makeRectangle(0, 0, SNAPSHOT, SNAPSHOT);					// make rectangle selection
 		waitForUser("Center the square on the cell of interest, then select 'OK'.");
 		run("Add Selection...", "stroke=none width=0 fill=black");	// fill square with black overlay
 		run("Crop");
 		roiManager("Select", 0);									// select the cell ROI
 		run("Add Selection...", "stroke=white width=0 fill=none");	// add the ROI to the overlay
 		run("Flatten");												// flatten to RGB image
 		saveAs("Tiff", cellFilesOutputDir + File.separator + cellName + "_ROI_Image.tif"); //save image
 		close();	// closes the new image
 		
	
		print("Closing the image...");
		// close the image and open the indented one
		close();
		secImg = File.openDialog("Select the indented image:");
		open(secImg);
	
		roiManager("Select", 0);		// step 8. select the outline ROI and add to image.
		run("ROI Manager...");
		waitForUser("Adjust the ROI to ensure it lies ontop of the indented cell, then select 'OK'.");
		run("Add Selection...");		// step 9. add selection to overlay

		locationName = "grand central station";			// opens dialog box to collect location name
		width = 512; height = 512;
		Dialog.create("Cell Location");
		Dialog.addString("Location:", locationName);
		Dialog.show();
		locationName = Dialog.getString();
	
		// ask the user to outline the area of the tip
		setTool("rectangle");
		waitForUser("Outline the tip, then select 'OK'.");
		run("Measure");											// Measure the tip --> potential bug: might measure the cell ROI instead. test further
		tipArea = Table.get("Area", indexOffset);
		setResult("Label", indexOffset, "Tip Area (microns)");	// note that the units are labeled microns here because they get converted in the same
		updateResults();										//	table later down the line, so it makes it consistent when saving the raw output
		setForegroundColor(255, 153, 0);
		run("Fill", "slice");
		indexOffset++;
	
		// ask the user to outline the overlapping area.
		setTool("polygon");
		waitForUser("Outline the area where the tip overlaps the cell, then select 'OK'.");
		run("Measure");
		overlapArea = Table.get("Area", indexOffset);
		setResult("Label", indexOffset, "Area of Overlap (microns)");
		updateResults();
		setForegroundColor(255, 255, 255);
		run("Fill", "slice");
		indexOffset++;
	
		setResult("X", 0, 0);	// set up x, y columns here so it doesn't delete past labels
		setResult("Y", 0, 0);
		
		// unfinished feature that use cell angle to do something in a coordinate plane
		// Not needed for area, width, length, and other measurements.
		if(doAngle) {
			setTool("multipoint");
			waitForUser("Click the leftmost point of the cell, then select 'OK'.");
			run("Measure");
			run("Select None");	//deselect the last point marker created so we don't measure it twice
			setResult("Label", indexOffset, "Leftmost Cell (microns)");
			x1 = Table.get("X", indexOffset);
			y1 = Table.get("Y", indexOffset);
			indexOffset++;
			waitForUser("Click the left bottom corner of the tip, then select 'OK'.");
			run("Measure");
			setResult("Label", indexOffset, "Leftmost Tip (microns)");
			x2 = Table.get("X", indexOffset);
			y2 = Table.get("Y", indexOffset);
			indexOffset++;
		
			xDist = x2 - x1;	//tabulate distance in x and y
			yDist = y2 - y1;
		
			run("Select None");
			setTool("angle");
			waitForUser("Measure the angle the cell makes with the tip (from the vertical axis, between +90* and -90*), then select 'OK'.");
			run("Measure");
			setResult("Label", indexOffset, "Angle From Tip (deg)");
			cellAngle = Table.get("Angle", indexOffset);
			indexOffset++;
			updateResults();
		} else {
			xDist = -1;
			yDist = -1;
			cellAngle = -1;
//			indexOffset += 3;			currently broken since we don't measure those things? look into further
		}
	
		// save the new image in .tiff format
		saveAs("Tiff", cellFilesOutputDir + File.separator + cellName + "_processed.tif");

		conversion = (tipArea) / 2500;		// has units pixels/micron		WHY DOES EVERY conversion VAR OPERATION AFTER THIS NEED ()???
		convertMeasure(conversion);			// convert measurements
		
		// add the last bits of data that won't be converted.
		setResult("Label", indexOffset, "Tip Area (Pixels)");
		Table.set("Area", indexOffset, tipArea);
		indexOffset++;
		setResult("Label", indexOffset, "Area of Overlap (Pixels)");
		Table.set("Area", indexOffset, overlapArea);
		updateResults();
		indexOffset++;
	
		// save the raw table.
		print("Producing raw data table...");
		if(printRaw){
			saveAs("Results", cellFilesOutputDir + File.separator + cellName + "_rawData.csv");	
		}
	
		// create and save the refined table
		print("Creating refined table...");
		
		pRefOffset = 0;					// used to offset the data in refined table
		
		if(usePRefine){					// if we're ammending data to an old table,
			Table.open(pRefine);		// open up the old table
			pRefOffset = Table.size;	// calibrate the offset
			prepareTable(pRefineName);	// open the table using special function
		}else {
			Table.create("Results"); 	// clears the data from the raw table
		}
		// format the table for saving
		print("Setting column headers...");
		setResult("Cell Title", pRefOffset, cellName);
		setResult("Folder", pRefOffset, 						imageDir);	// put in image's file path
		setResult("fileName", pRefOffset, 						cellName);							
		setResult("Location", pRefOffset, 						locationName);
		setResult("Cell Average Length (pixels)", pRefOffset, 	meanLength);// input Average Length
		setResult("Cell Average Width (pixels)", pRefOffset, 	meanWidth);	// input Average Width
		setResult("Cell Area (pixels)", pRefOffset, 			cellArea);	// input Area
		setResult("Tip Area (pixels)", pRefOffset, 				tipArea);	// input tip area
		setResult("Pixels/micron", pRefOffset, 					conversion);
		setResult("Overlapping Area (pixels)", pRefOffset, 		overlapArea);
		setResult("X distance (pixels)", pRefOffset, 			xDist);				
		setResult("Y distance (pixels)", pRefOffset, 			yDist);				
		setResult("Angle (deg)", pRefOffset, 					cellAngle);										
		
		setResult("Cell Average Length (um)", pRefOffset, (meanLength) / (conversion));	// input Average Length
		setResult("Cell Average Width (um)", pRefOffset, (meanWidth) / (conversion));	// input Average Width
		setResult("Cell Area (um)", pRefOffset, (cellArea) / (conversion));				// input Area
		setResult("Overlapping Area (um)", pRefOffset, (overlapArea) / (conversion));	// input Area
		setResult("Percent of Tip in Contact with Cell", pRefOffset, (overlapArea) / (tipArea));
		setResult("X distance (pixels)", pRefOffset, xDist);				
		setResult("Y distance (pixels)", pRefOffset, yDist);
		
		updateResults();
		print("Saving refined table...");
	
		// if we're saving to a previously refined table, save to that same directory.
		if(usePRefine){
			saveAs("Results", pRefineDir + File.separator + pRefineName);
			closeTable(pRefineName);
			selectWindow(pRefineName);
			run("Close");
		// otherwise, create a new refined table with the same output as the other data.
		}else{
			saveAs("Results", cellFilesOutputDir + File.separator + cellName + "_Data.csv");	
		}

		// close the processed image, Results table, and ROI manager
		selectWindow(cellName + "_processed.tif");
//		run("Close");
//		close("*");
		close();
		Table.create("Results");
		roiManager("reset");
	
	} else {
		exit("No area selected. Exiting Macro...");
	}
	print("Macro finished!");
}



/*#################################################################################################
										FUNCTIONS	
#################################################################################################*/

// takes indexOffset, collects n measurements (n = sampNum), and returns the average value of them.
function getAverage(indexOS, sampNum) {
	sum = 0;
	for (i = 0; i < sampNum; i++) {
		adder = Table.get("Length", i + indexOS);
		sum = sum + adder;
	}
	result = (sum) / (sampNum);
	return result;
}

// takes indexOffset, a capitalized labeling string, and a sampleNum and asks the user to take n measurements
// (n = sampleNum). It then measures the selections and labels them accordingly.
function measureLoop(indexOS, label, sampNum) {
	for (i = 0; i < sampNum; i++) {
		waitForUser("[" + (i + 1) + "/" + sampNum + "] Measure the " + label + " of the cell, then press 'OK'");
		run("Measure");
		setResult("Label", (i + indexOS), label + " (um) " + (i + 1));
		updateResults();
	}
}

// takes the ratio of pixels/micron and converts all the measuremnts in the "Area" and "Length" columns into SI units.
function convertMeasure(ratio){
	for(i = 0; i < Table.size; i++){
		area = Table.get("Area", i);	// get the area
		newArea = (area) / (ratio);			// utilize the ratio to cancel out pixels and get microns
		Table.set("Area", i, newArea);		// replace the value in pixels with the value in mirons.
		
		length = Table.get("Length", i);
		newLength = (length) / (ratio);
		Table.set("Length", i, newLength);
	}
}

// The following functions were made by Oliver Burri on the image.sc forums.
// https://forum.image.sc/t/update-a-personalized-resultstable/1967/6

// Prepare a new table or an existing table to receive results. 
function prepareTable(tableName) { 
		updateResults(); 
		if(isOpen("Results")) { IJ.renameResults("Results","Temp"); updateResults();} 
		if(isOpen(tableName)) { IJ.renameResults(tableName,"Results"); updateResults();} 
} 
// Once we are done updating the results, close the results table 
// and give it its final name 
function closeTable(tableName) { 
		updateResults(); 
		if(isOpen("Results")){ IJ.renameResults("Results",tableName); updateResults();} 
		if(isOpen("Temp")) { IJ.renameResults("Temp","Results"); updateResults();} 
}