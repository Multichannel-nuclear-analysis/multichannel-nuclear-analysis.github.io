// ImageJ Macro for Merging Multiple Channel Images
// This macro finds TIF files with the same base name but different channel suffixes,
// merges them, and saves the result in a new directory.

// === CONFIGURATION SECTION - MODIFY THESE PARAMETERS AS NEEDED ===
// Default values - these will be overridden by user input
var outputDir = "Merged TIF files";
var num_channels = 3; // Default number of channels
var suffixes = newArray(10); // Will store channel suffixes (expanded based on user input)
var colors = newArray(10); // Will store channel colors (expanded based on user input)
// === END CONFIGURATION SECTION ===

// Function for logging messages
function logMessage(message) {
    print(message);
    // Check if Log window is open and logPath variable has been initialized
    if (isOpen("Log") && lengthOf("" + logPath) > 0) {
        File.append(message, logPath);
    }
}

function getFormattedDateTime() {
    // Declare variables before calling getDateAndTime
    var year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec;
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    return "" + year + "-" + IJ.pad((month+1), 2) + "-" + IJ.pad(dayOfMonth, 2) + " " + 
           IJ.pad(hour, 2) + ":" + IJ.pad(minute, 2) + ":" + IJ.pad(second, 2);
}

// First dialog: get number of channels
function showChannelCountDialog() {
    Dialog.create("Multi-Channel Merge - Step 1 of 2");
    Dialog.addMessage("Welcome to the Multi-Channel Merge tool.\nThis tool merges single-channel TIF files into multichannel composite images.");
    Dialog.addNumber("Number of channels to merge:", 3, 0, 2, "");
    Dialog.addString("Output directory name:", outputDir);
    
    Dialog.show();
    
    // Get the values
    num_channels = Dialog.getNumber();
    outputDir = Dialog.getString();
    
    if (num_channels < 1 || num_channels > 10) {
        showMessage("Error", "Number of channels must be between 1 and 10");
        return false;
    }
    
    return true;
}

// Second dialog: get channel details
function showChannelDetailsDialog() {
    // Default values for suffixes and colors
    defaultSuffixes = newArray("-DAPI", "-Nanog", "-mCherry", "-GFP", "-FITC", "-Cy5", "-Cy3", "-TRITC", "-Channel9", "-Channel10");
    defaultColors = newArray("blue", "green", "red", "cyan", "magenta", "yellow", "grays", "orange hot", "glasbey", "ICA");
    
    // Create the dialog
    Dialog.create("Multi-Channel Merge - Step 2 of 2");
    Dialog.addMessage("Configure each channel's suffix and color (LUT)");
    
    // Color options for dropdown
    colorOptions = getAvailableLUTs();
    
    // Add configuration for each channel
    for (i = 0; i < num_channels; i++) {
        Dialog.addMessage("--- Channel " + (i+1) + " ---");
        Dialog.addString("Suffix for channel " + (i+1) + ":", defaultSuffixes[i]);
        Dialog.addChoice("Color (LUT) for channel " + (i+1) + ":", colorOptions, defaultColors[i]);
    }
    
    Dialog.show();
    
    // Get the values
    for (i = 0; i < num_channels; i++) {
        suffixes[i] = Dialog.getString();
        colors[i] = Dialog.getChoice();
    }
    
    // Resize arrays to actual number of channels
    suffixes = Array.slice(suffixes, 0, num_channels);
    colors = Array.slice(colors, 0, num_channels);
    
    return true;
}

// Get available LUTs from ImageJ
function getAvailableLUTs() {
    // Predefined common LUTs to show at the top
    preferredLUTs = newArray("Grays", "Red", "Green", "Blue", "Cyan", "Magenta", "Yellow", 
                            "Orange Hot", "Fire", "Thermal", "Turquoise", "Magenta Hot", "Cyan Hot");
    
    // Get all LUTs from ImageJ's LUTs directory
    lutDirectory = getDirectory("luts");
    finalLUTs = newArray();
    
    // Add preferred LUTs at the top
    for (i = 0; i < preferredLUTs.length; i++) {
        finalLUTs = Array.concat(finalLUTs, preferredLUTs[i]);
    }
    
    // If we have a LUT directory, add the rest
    if (lutDirectory != "") {
        lutFiles = getFileList(lutDirectory);
        
        // Add all other LUTs
        for (i = 0; i < lutFiles.length; i++) {
            if (endsWith(lutFiles[i], ".lut")) {
                lutName = substring(lutFiles[i], 0, lengthOf(lutFiles[i])-4);
                // Check if it's already in our preferred list
                isPreferred = false;
                for (j = 0; j < preferredLUTs.length; j++) {
                    if (lutName == preferredLUTs[j]) {
                        isPreferred = true;
                        break;
                    }
                }
                
                // Add if not already in preferred list
                if (!isPreferred) {
                    finalLUTs = Array.concat(finalLUTs, lutName);
                }
            }
        }
    }
    
    // If we don't have any LUTs, use some defaults
    if (finalLUTs.length == 0) {
        finalLUTs = newArray("Red", "Green", "Blue", "Cyan", "Magenta", "Yellow", "Grays");
    }
    
    return finalLUTs;
}

function mergeChannels() {
    // Ask for input directory
    dir = getDirectory("Choose a Directory with TIF Images");
    
    // Create log file after directory is selected
    logPath = dir + "merge_log.txt";
    File.saveString("=== Merge Log Started: " + getFormattedDateTime() + " ===\n", logPath);
    
    // Create output directory if it doesn't exist
    outDir = dir + File.separator + outputDir + File.separator;
    if (!File.exists(outDir)) {
        File.makeDirectory(outDir);
    }
    
    // Get all files in the directory
    fileList = getFileList(dir);
    
    // Get unique base names
    baseNames = getUniqueBaseNames(fileList);
    
    // Process each base name
    setBatchMode(true);
    n = baseNames.length;
    showProgress(0);
    
    for (i = 0; i < baseNames.length; i++) {
        baseName = baseNames[i];
        logMessage("Processing: " + baseName);
        
        // Find all channel files for this base name
        channelFiles = findChannelFiles(dir, baseName, suffixes);
        
        // If we found all channels, merge them
        if (channelFiles.length == suffixes.length) {
            mergeAndSaveImage(channelFiles, baseName, outDir);
        } else {
            logMessage("Warning: Not all channels found for " + baseName);
            logMessage("Expected: " + suffixes.length + " channels, found: " + channelFiles.length);
        }
        
        showProgress(i+1, n);
        showStatus("Processing image " + (i+1) + "/" + n + ": " + baseName);
    }
    
    logMessage("Process completed. Merged images saved to: " + outDir);
}

function getUniqueBaseNames(fileList) {
    // Extract unique base names from file list
    baseNamesMap = newArray();
    count = 0;
    
    for (i = 0; i < fileList.length; i++) {
        fileName = fileList[i];
        if (endsWith(fileName, ".tif") || endsWith(fileName, ".TIF")) {
            // Try to find a matching suffix
            for (j = 0; j < suffixes.length; j++) {
                suffix = suffixes[j];
                if (endsWith(fileName, suffix + ".tif") || endsWith(fileName, suffix + ".TIF")) {
                    // Extract base name (remove suffix and extension)
                    baseName = substring(fileName, 0, lastIndexOf(fileName, suffix));
                    
                    // Check if base name already exists in our array
                    exists = false;
                    for (k = 0; k < count; k++) {
                        if (baseNamesMap[k] == baseName) {
                            exists = true;
                            break;
                        }
                    }
                    
                    // Add if not found
                    if (!exists) {
                        baseNamesMap[count] = baseName;
                        count++;
                    }
                    break;
                }
            }
        }
    }
    
    // Create final array with proper size
    baseNames = newArray(count);
    for (i = 0; i < count; i++) {
        baseNames[i] = baseNamesMap[i];
    }
    
    return baseNames;
}

function findChannelFiles(dir, baseName, suffixes) {
    channelFiles = newArray(suffixes.length);
    
    for (i = 0; i < suffixes.length; i++) {
        suffix = suffixes[i];
        found = false;
        
        // Try different extensions with exact case matching
        extensions = newArray(".tif", ".TIF", ".tiff", ".TIFF");
        for (j = 0; j < extensions.length; j++) {
            filename = baseName + suffix + extensions[j];
            if (File.exists(dir + filename)) {
                channelFiles[i] = dir + filename;
                found = true;
                break;
            }
        }
        
        if (!found) {
            channelFiles[i] = "";
            logMessage("Warning: Could not find file for " + baseName + suffix + " (exact match only)");
        }
    }
    
    return channelFiles;
}

function mergeAndSaveImage(channelFiles, baseName, outDir) {
    // Arrays to track opened images and their corresponding colors
    channelImageNames = newArray(channelFiles.length);
    channelColors = newArray(channelFiles.length);
    
    // Open all channel images
    for (i = 0; i < channelFiles.length; i++) {
        if (channelFiles[i] != "") {
            open(channelFiles[i]);
            // Get the title of the opened image
            channelImageNames[i] = getTitle();
            // Store the color that corresponds to this channel
            channelColors[i] = colors[i];
        } else {
            // Create an empty image if channel is missing
            emptyName = "Empty_" + i;
            newImage(emptyName, "16-bit black", 512, 512, 1);
            channelImageNames[i] = emptyName;
            channelColors[i] = colors[i];
            logMessage("Created empty placeholder for missing channel");
        }
    }
    
    // Check image sizes and normalize bit depth
    if (!checkImageSizes(channelImageNames)) {
        // Close all images if sizes don't match
        close("*");
        return;
    }
    
    // Normalize bit depth
    checkAndNormalizeBitDepth(channelImageNames);
    
    // Create merged image using Merge Channels command
    channelString = "";
    
    for (i = 0; i < channelImageNames.length; i++) {
        if (i > 0) {
            channelString += " ";
        }
        channelString += "c" + (i+1) + "=[" + channelImageNames[i] + "]";
    }
    
    // Merge channels (without specifying colors in the merge command)
    mergeCommand = channelString + " create";
    run("Merge Channels...", mergeCommand);
    
    // The result is a composite image
    mergedImage = getTitle();
    
    // Apply the LUTs after merging (this is more reliable)
    for (i = 0; i < channelColors.length; i++) {
        Stack.setChannel(i+1);
        run(channelColors[i]);
        logMessage("Applied LUT '" + channelColors[i] + "' to channel " + (i+1));
    }
    
    // Save as a composite image
    saveAs("Tiff", outDir + baseName + ".tif");
    
    // Close all images
    close("*");
}

function checkImageSizes(channelImageNames) {
    if (channelImageNames.length == 0) return true;
    
    // Get reference dimensions
    selectWindow(channelImageNames[0]);
    refWidth = getWidth();
    refHeight = getHeight();
    
    // Check all others match
    for (i = 1; i < channelImageNames.length; i++) {
        if (channelImageNames[i] != "") {
            selectWindow(channelImageNames[i]);
            currWidth = getWidth();
            currHeight = getHeight();
            
            if (currWidth != refWidth || currHeight != refHeight) {
                showMessage("Error", "Channel images have different dimensions!\n" +
                           channelImageNames[0] + ": " + refWidth + "x" + refHeight + "\n" + 
                           channelImageNames[i] + ": " + currWidth + "x" + currHeight);
                return false;
            }
        }
    }
    return true;
}

function checkAndNormalizeBitDepth(channelImageNames) {
    // Find highest bit depth among all channels
    maxBitDepth = 0;
    for (i = 0; i < channelImageNames.length; i++) {
        if (channelImageNames[i] != "") {
            selectWindow(channelImageNames[i]);
            currentBitDepth = bitDepth();
            if (currentBitDepth > maxBitDepth) {
                maxBitDepth = currentBitDepth;
            }
        }
    }
    
    // Convert all to the highest bit depth if needed
    for (i = 0; i < channelImageNames.length; i++) {
        if (channelImageNames[i] != "") {
            selectWindow(channelImageNames[i]);
            currentBitDepth = bitDepth();
            if (currentBitDepth < maxBitDepth) {
                if (maxBitDepth == 16) {
                    run("16-bit");
                } else if (maxBitDepth == 32) {
                    run("32-bit");
                }
            }
        }
    }
    
    return maxBitDepth;
}

// Run the script with new two-step dialog approach
if (showChannelCountDialog()) {
    if (showChannelDetailsDialog()) {
        // Run the main function
        mergeChannels();
    } else {
        print("Channel configuration canceled. Macro aborted.");
    }
} else {
    print("Configuration canceled or invalid. Macro aborted.");
}