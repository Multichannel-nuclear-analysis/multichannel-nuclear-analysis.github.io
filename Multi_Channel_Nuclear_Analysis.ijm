// ImageJ Macro Plugin
// Title: Multi-Channel Analysis
// Shortcut: none
// Menu: Plugins>Multi-Channel Nuclear Analysis>Run Analysis
// Description: GUI-based tool for analyzing multi-channel fluorescence images
// Author: Ariel Waisman
// Version: 1.0
// Date: 2025

// Multi-channel Fluorescence Image Analysis Macro with GUI
// Description: Analyzes multi-channel fluorescence images with configurable parameters via GUI

// Check if StarDist and CSBDeep are installed
if (!areRequiredPluginsInstalled()) {
    exit("Required plugins are missing.\n \nPlease install the following plugins from the update sites:\n1. Help > Update...\n2. Click 'Manage update sites'\n3. Check both 'StarDist' AND 'CSBDeep'\n4. Click 'Close'\n5. Click 'Apply Changes'\n6. Restart ImageJ/FIJI");
}

// Function to check if required plugins are installed
function areRequiredPluginsInstalled() {
    // Check if both StarDist and CSBDeep are installed
    return isPluginInstalled("StarDist") && isPluginInstalled("CSBDeep");
}

// Function to check if a specific plugin is installed
function isPluginInstalled(pluginName) {
    // Get plugins directory
    pluginsDir = getDirectory("plugins");
    
    if (pluginName == "StarDist") {
        // Check if the StarDist JAR exists directly in plugins folder
        if (File.exists(pluginsDir + "StarDist_.jar") || 
            File.exists(pluginsDir + "StarDist")) {
            return true;
        }
        
        // Check if jar exists recursively in plugins dir
        files = getFileList(pluginsDir);
        for (i=0; i<files.length; i++) {
            if (startsWith(files[i], "StarDist_") && endsWith(files[i], ".jar")) {
                return true;
            }
        }
    }
    else if (pluginName == "CSBDeep") {
        // Check if the CSBDeep JAR exists directly in plugins folder
        if (File.exists(pluginsDir + "CSBDeep_.jar") || 
            File.exists(pluginsDir + "CSBDeep")) {
            return true;
        }
        
        // Check if jar exists recursively in plugins dir
        files = getFileList(pluginsDir);
        for (i=0; i<files.length; i++) {
            if (startsWith(files[i], "CSBDeep_") && endsWith(files[i], ".jar")) {
                return true;
            }
        }
    }
    
    // Check if jar in any of the subdirectories (e.g., from update site)
    subdirs = getSubDirectories(pluginsDir);
    for (i=0; i<subdirs.length; i++) {
        subFiles = getFileList(subdirs[i]);
        for (j=0; j<subFiles.length; j++) {
            if (pluginName == "StarDist" && startsWith(subFiles[j], "StarDist_") && endsWith(subFiles[j], ".jar")) {
                return true;
            }
            else if (pluginName == "CSBDeep" && startsWith(subFiles[j], "CSBDeep_") && endsWith(subFiles[j], ".jar")) {
                return true;
            }
        }
    }
    
    // Also verify if the commands exist (might be installed differently)
    List.setCommands;
    if (pluginName == "StarDist" && (List.get("StarDist 2D") != "" || List.get("de.csbdresden.stardist.StarDist2D") != "")) {
        return true;
    }
    else if (pluginName == "CSBDeep" && (List.get("CSBDeep") != "" || List.get("de.csbdresden.csbdeep") != "")) {
        return true;
    }
    
    return false;
}

// Helper function to get subdirectories
function getSubDirectories(dir) {
    list = getFileList(dir);
    result = newArray(0);
    
    for (i=0; i<list.length; i++) {
        if (endsWith(list[i], "/")) {
            result = Array.concat(result, dir + list[i]);
        }
    }
    
    return result;
}

// Multi-Channel Nuclear Analysis Script for Fiji ImageJ
//
// Created by Martín Waisman
// FLENI, Buenos Aires, Argentina
// martin.waisman@gmail.com
//
// Version 3.0.2 (2024)
// License: Public Domain
//
//--------------------------------------------------

// Define global variables
var background_value = 0;  // Default background value
var use_rolling_ball = false;  // Default to not using rolling ball method
var output_dir = "";      // Output directory for results
var first_channel = 0;    // First active channel (for configuration checks)
var debug_mode = false;   // Debug mode flag
var save_ROI_set = false; // Flag to save ROI set
var create_merge = true;  // Flag to create merged image
var analyze_batch = false; // Flag to indicate batch mode
var rolling_bg_value = 0;  // Stores the rolling background mean
var rolling_bg_suffix = ""; // Stores the channel suffix for the rolling background

// Define channel configuration arrays
var channel_active = newArray(4);
var channel_title = newArray(4);
var channel_background = newArray(4);
var channel_display_max = newArray(4);
var channel_lut = newArray(4);
var channel_suffixes = newArray(4);
var channel_use_rolling_ball = newArray(4);

// Global variables for storing user choices
var channel_active = newArray(4);
var channel_background = newArray(4);
var channel_max_display = newArray(4);
var channel_colors = newArray(4);
var channel_suffixes = newArray(4);
var merge_channels = newArray(4);
var channel_use_rolling_ball = newArray(4); // New array to track if rolling ball method should be used
var segmentation_channel = 1;
var num_channels = 4; // Number of channels selected by user
var channelPage = 0;  // Current page in the channel configuration dialog

// Initialize arrays with -1 to detect first run
for (i=0; i<4; i++) {
    channel_active[i] = -1;
    channel_background[i] = -1;
    channel_max_display[i] = -1;
    channel_colors[i] = "";
    channel_suffixes[i] = "";
    merge_channels[i] = -1;
    channel_use_rolling_ball[i] = false; // Initialize rolling ball method to false
}

// Default values
var default_colors = newArray("Blue", "Green", "Red", "Grays");
var default_suffixes = newArray("_Channel1", "_Channel2", "_Channel3", "_Channel4");
var default_backgrounds = newArray(0, 0, 0, 0);
var default_max_displays = newArray(16000, 16000, 16000, 16000);

// StarDist Parameters (fixed as requested)
var stardist_model = "Versatile (fluorescent nuclei)";
var prob_thresh = 0.5;
var nms_thresh = 0.4;
var exclude_boundary = 2;

// Show configuration dialogs
var step = 0; // Start with welcome dialog
while (step >= 0) {
    if (step == 0) {
        step = showWelcomeDialog();
    } else if (step == 1) {
        step = showChannelDialog();
    } else if (step == 2) {
        step = showMergeSegmentDialog();
    }
}

// ---- MAIN SCRIPT ----

run("Close All");
//setBatchMode(true);

// Select input directory
dir = getDirectory("Choose input directory");
list = getFileList(dir);

// Create output directory
output_dir = dir + "Analysis" + File.separator;
File.makeDirectory(output_dir);

// Save parameters to a text file for reference
saveParametersToFile(output_dir);

// Process each file
for (i=0; i<list.length; i++) {
    if (matches(list[i], ".*\\.(czi|tif|tiff)$")) {
        processFile(dir, list[i], output_dir);
    }
}

// Generate a combined CSV with data from all images
generateCompleteDataFile(output_dir);

// ---- GUI FUNCTIONS ----

function showWelcomeDialog() {
    // Create welcome dialog
    Dialog.create("Welcome to Multi-Channel Nuclear Analysis");
    
    // Add welcome message
    Dialog.addMessage("Welcome to the Multi-Channel Nuclear Analysis plugin.\n"+
                      "This tool uses Stardist to segment nuclei and lets you\nanalyze multi-channel fluorescence images with customizable\nparameters. "+
                      "You can set measurement parameters,\nconfigure channels,and perform nuclear segmentation.\nThe plugin generates CSV data tables for further analysis");
    
    // Add dropdown to select number of channels
    channelOptions = newArray("1", "2", "3", "4");
    Dialog.addChoice("Number of channels in your images:", channelOptions, "2");
    
    // Add button to open Set Measurements dialog
    Dialog.addMessage("Click the button below to configure which measurements to include:");
    Dialog.addCheckbox("Open 'Set Measurements' dialog", true);
    
    // Add OK button
    Dialog.show();
    
    // Process user choices
    selectedChannels = Dialog.getChoice();
    num_channels = parseInt(selectedChannels);
    
    // Initialize active channels based on selection
    for (i=0; i<4; i++) {
        if (i < num_channels) {
            channel_active[i] = true;
            // Set default values for active channels if not already set
            if (channel_background[i] == -1) channel_background[i] = default_backgrounds[i];
            if (channel_max_display[i] == -1) channel_max_display[i] = default_max_displays[i];
            if (channel_colors[i] == "") channel_colors[i] = default_colors[i];
            if (channel_suffixes[i] == "") channel_suffixes[i] = default_suffixes[i];
        } else {
            channel_active[i] = false;
            merge_channels[i] = false;
        }
    }
    
    // Open measurement dialog if requested
    if (Dialog.getCheckbox()) {
        run("Set Measurements...");
    }
    
    return 1; // Proceed to channel configuration dialog
}

function getAvailableLUTs() {
    // Get FIJI's LUTs directory
    lutDir = getDirectory("luts");
    if (lutDir == "") {
        // If no LUTs directory found, return default colors
        return default_colors;
    }
    
    // Get list of LUT files
    lutFiles = getFileList(lutDir);
    
    // Define the preferred order of LUTs
    preferredLUTs = newArray("Grays", "Red", "Green", "Blue", "Cyan", "Magenta", "Yellow");
    
    // Filter for .lut files and convert to color names
    luts = newArray(0);
    for (i=0; i<lutFiles.length; i++) {
        if (endsWith(lutFiles[i], ".lut")) {
            // Convert filename to color name (remove .lut extension)
            colorName = replace(lutFiles[i], "\\.lut$", "");
            luts = Array.concat(luts, colorName);
        }
    }
    
    // Create final array starting with preferred LUTs
    finalLUTs = newArray(0);
    
    // First add preferred LUTs in the specified order
    for (i=0; i<preferredLUTs.length; i++) {
        finalLUTs = Array.concat(finalLUTs, preferredLUTs[i]);
    }
    
    // Then add remaining LUTs in alphabetical order
    remainingLUTs = newArray(0);
    for (i=0; i<luts.length; i++) {
        // Check if this LUT is not in the preferred list
        isPreferred = false;
        for (j=0; j<preferredLUTs.length; j++) {
            if (luts[i] == preferredLUTs[j]) {
                isPreferred = true;
                break;
            }
        }
        if (!isPreferred) {
            remainingLUTs = Array.concat(remainingLUTs, luts[i]);
        }
    }
    
    // Sort remaining LUTs alphabetically
    for (i=0; i<remainingLUTs.length-1; i++) {
        for (j=i+1; j<remainingLUTs.length; j++) {
            if (remainingLUTs[i] > remainingLUTs[j]) {
                temp = remainingLUTs[i];
                remainingLUTs[i] = remainingLUTs[j];
                remainingLUTs[j] = temp;
            }
        }
    }
    
    // Add remaining LUTs to final array
    for (i=0; i<remainingLUTs.length; i++) {
        finalLUTs = Array.concat(finalLUTs, remainingLUTs[i]);
    }
    
    return finalLUTs;
}

function showChannelDialog() {
    // Get available LUTs once
    availableLUTs = getAvailableLUTs();
    
    // For 1-2 channels, show all in one dialog
    // For 3-4 channels, show 2 per page with navigation
    
    // Calculate total pages needed
    totalPages = Math.ceil(num_channels / 2);
    
    // Create appropriate dialog title
    dialogTitle = "Channel Configuration - Step 2/3";
    if (totalPages > 1) {
        dialogTitle += " (Page " + (channelPage + 1) + "/" + totalPages + ")";
    }
    
    Dialog.create(dialogTitle);
    Dialog.addMessage("Configure settings for each channel.\nClick 'Next' to proceed to the next channels or 'Continue' when done.");
    
    // Calculate which channels to show on this page
    startChannel = channelPage * 2;
    endChannel = Math.min(startChannel + 2, num_channels);
    
    // Only show configuration for channels on current page
    for (ch=startChannel; ch<endChannel; ch++) {
        i = ch; // Index for accessing arrays
        
        Dialog.addMessage("---------- Channel " + (i+1) + " ----------");
        
        // Get default or previously set values
        ch_bg = default_backgrounds[i];
        if (channel_background[i] != -1) {
            ch_bg = channel_background[i];
        }
        
        ch_max = default_max_displays[i];
        if (channel_max_display[i] != -1) {
            ch_max = channel_max_display[i];
        }
        
        ch_color = default_colors[i];
        if (channel_colors[i] != "") {
            ch_color = channel_colors[i];
        }
        
        ch_suffix = default_suffixes[i];
        if (channel_suffixes[i] != "") {
            ch_suffix = channel_suffixes[i];
        }
        
        Dialog.addNumber("Background / Radius", ch_bg);
        Dialog.addCheckbox("Use rolling ball method for background subtraction. Set the radius in pixels in the textbox above", channel_use_rolling_ball[i]);
        Dialog.addMessage("");
       //Dialog.addMessage("   When rolling ball is checked, set the radius in pixels in the box above");
        Dialog.addNumber("Max Display", ch_max);
        Dialog.addChoice("Color", availableLUTs, ch_color);
        Dialog.addString("Suffix", ch_suffix);
    }
    
    // Add navigation control
    Dialog.addMessage("\nNavigation:");
    
    // Different navigation options based on number of channels and current page
    navOptions = newArray();
    if (totalPages > 1) {
        // Multi-page dialog
        if (channelPage == 0) {
            // First page
            navOptions = newArray("Next Channels", "Go Back to Welcome Dialog");
        } else if (channelPage == totalPages - 1) {
            // Last page
            navOptions = newArray("Continue to Next Step", "Previous Channels", "Go Back to Welcome Dialog");
        } else {
            // Middle pages
            navOptions = newArray("Next Channels", "Previous Channels", "Go Back to Welcome Dialog");
        }
    } else {
        // Single page dialog
        navOptions = newArray("Continue to Next Step", "Go Back to Welcome Dialog");
    }
    
    Dialog.addChoice("Action", navOptions, navOptions[0]);
    
    Dialog.show();
    
    // Store the results for channels on this page
    for (i=startChannel; i<endChannel; i++) {
        channel_background[i] = Dialog.getNumber();
        channel_use_rolling_ball[i] = Dialog.getCheckbox();
        channel_max_display[i] = Dialog.getNumber();
        channel_colors[i] = Dialog.getChoice();
        channel_suffixes[i] = Dialog.getString();
    }
    
    // Check navigation choice
    navChoice = Dialog.getChoice();
    
    if (navChoice == "Next Channels") {
        channelPage++;
        return 1;  // Stay in channel dialog, next page
    } else if (navChoice == "Previous Channels") {
        channelPage--;
        return 1;  // Stay in channel dialog, previous page
    } else if (navChoice == "Go Back to Welcome Dialog") {
        // Reset page counter
        channelPage = 0;
        return 0;  // Go back to welcome dialog
    } else {
        // Must be "Continue to Next Step"
        // Reset page counter for next time
        channelPage = 0;
        return 2;  // Go to merge/segment dialog
    }
}

function showMergeSegmentDialog() {
    Dialog.create("Merge and Segmentation Configuration - Step 3/3");
    
    Dialog.addMessage("Select channels to include in merge (only for visualization):");
    for (i=0; i<num_channels; i++) {
        if (channel_active[i]) {
            merge_default = (i < 2);
            if (merge_channels[i] != -1) {
                merge_default = merge_channels[i];
            }
            Dialog.addCheckbox("Include Channel " + (i+1) + " in merge", merge_default);
        }
    }
    
    Dialog.addMessage("\nSelect segmentation channel:");
    channels = newArray();
    labels = newArray();
    for (i=0; i<num_channels; i++) {
        if (channel_active[i]) {
            channels = Array.concat(channels, i+1);
            labels = Array.concat(labels, "Channel " + (i+1));
        }
    }
    
    if (labels.length > 0) {
    Dialog.addChoice("Segmentation Channel", labels, labels[0]);
    } else {
        Dialog.addMessage("Warning: No active channels available for segmentation.");
    }
    
    // Add navigation control
    Dialog.addMessage("\nNavigation:");
    navOptions = newArray("Finish", "Back to Channel Configuration", "Back to Welcome Dialog");
    Dialog.addChoice("Action", navOptions, "Finish");
    
    Dialog.show();
    
    // Store merge choices
    mergeIndex = 0;
    for (i=0; i<num_channels; i++) {
        if (channel_active[i]) {
            merge_channels[i] = Dialog.getCheckbox();
            mergeIndex++;
        } else {
            merge_channels[i] = false;
        }
    }
    
    // Store segmentation choice only if we have active channels
    if (labels.length > 0) {
    choice = Dialog.getChoice();
    segmentation_channel = parseInt(choice.replace("Channel ", ""));
    }
    
    // Check navigation choice
    navChoice = Dialog.getChoice();
    if (navChoice == "Back to Channel Configuration")
        return 1;  // Go back to channel dialog
    else if (navChoice == "Back to Welcome Dialog")
        return 0;  // Go back to welcome dialog
    
    return -1;      // Finish configuration
}

// ---- PROCESSING FUNCTIONS ----

function processFile(dir, file, output_dir) {
    print("----------------------------");
    print("Processing file: " + file);
    
    // Open file
    path = dir + file;
    
    // Check file extension to determine how to open it
    if (matches(file, ".*\\.czi$")) {
        // Use Bio-Formats for CZI files
    run("Bio-Formats Importer", "open=["+path+"]" + " color_mode=Default view=Hyperstack stack_order=XYCZT");
    } else {
        // Use standard ImageJ opener for TIF files
        run("Open...", "path=["+path+"]");
    }
    
    // Get base filename
    titulo = getTitle();
    titulo_base = replace(titulo, "\\.(czi|tif|tiff)$", "");
    
    // Validate channel count
    validateChannelCount(titulo);
    
    // Process segmentation channel first
    if (segmentation_channel > 0) {
        processSegmentationChannel(titulo, titulo_base, segmentation_channel);
    }
    
    // Process each active channel
    for (i=0; i<4; i++) {
        if (channel_active[i]) {
            channel_config = newArray(true, i+1, channel_background[i], 
                                   channel_max_display[i], channel_colors[i], 
                                   channel_suffixes[i], channel_use_rolling_ball[i]);
            processChannel(titulo, titulo_base, channel_config);
        }
    }
    
    // Create combined CSV with measurements from all channels
    if (roiManager("count") > 0) {
        createCombinedMeasurements(titulo_base, output_dir);
    }
    
    // Create merge if needed
    if (arraySum(merge_channels) > 0) {
        createMerge(titulo, titulo_base);
    }
    
    run("Close All");
}

// Function to validate if the number of channels in the image matches user selection
function validateChannelCount(image_title) {
    // Get the actual number of channels in the image
    selectWindow(image_title);
    getDimensions(width, height, actual_channels, slices, frames);
    
    // Compare with user-defined number
    if (actual_channels != num_channels) {
        showMessage("Channel Count Warning", 
            "The image '" + image_title + "' has " + actual_channels + " channels, " +
            "but you configured the analysis for " + num_channels + " channels.\n\n" +
            "This may affect your results or cause errors during processing.");
        
        print("WARNING: Channel count mismatch. Image has " + actual_channels + 
              " channels, but analysis is configured for " + num_channels + " channels.");
    }
}

function processSegmentationChannel(titulo, titulo_base, channel_num) {
    // Get the channel settings
    maxDisplay = channel_max_display[channel_num-1];
    colorName = channel_colors[channel_num-1];
    
    // Duplicate segmentation channel
    selectWindow(titulo);
    titulo_seg = titulo_base + "_segmentation";
    run("Duplicate...", "title='"+titulo_seg+"' duplicate channels="+channel_num);
    
    // Save a copy of the original image with proper display settings for later use
    selectWindow(titulo_seg);
    originalImage = titulo_seg + "_original";
    run("Duplicate...", "title='"+originalImage+"'");
    selectWindow(originalImage);
    
    // Apply background subtraction if needed
    background = channel_background[channel_num-1];
    if (background > 0) {
        if (channel_use_rolling_ball[channel_num-1]) {
            // Use rolling ball method with the specified radius
            run("Subtract Background...", "rolling=" + background);
        } else {
            // Use traditional background subtraction
            run("Subtract...", "value=" + background);
        }
    }
    
    // Apply the color and display settings
    run(colorName);
    setMinAndMax(0, maxDisplay);
    
    // Return to the StarDist processing
    selectWindow(titulo_seg);
    
    // Run StarDist
    run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], " +
        "args=['input':'"+titulo_seg+"', " +
        "'modelChoice':'"+stardist_model+"', " +
        "'normalizeInput':'true', " +
        "'percentileBottom':'1.0', " +
        "'percentileTop':'99.8', " +
        "'probThresh':'"+prob_thresh+"', " +
        "'nmsThresh':'"+nms_thresh+"', " +
        "'outputType':'Both', " +
        "'nTiles':'1', " +
        "'excludeBoundary':'"+exclude_boundary+"', " +
        "'roiPosition':'Automatic', " +
        "'verbose':'false', " +
        "'showCsbdeepProgress':'false', " +
        "'showProbAndDist':'false'], " +
        "process=[false]");
    
    // Clean up intermediate image
    selectWindow("Label Image");
    close();
    
    // Now work with our pre-processed original image that has proper display settings
    selectWindow(originalImage);
    
    // Show ROIs on this properly displayed image
    roiManager("Show All without labels"); 
    run("Flatten");
    
    // Save with the proper name
    saveAs("PNG", output_dir + titulo_base + "_segmentation");
    close();
    
    // Clean up
    if (isOpen(originalImage)) {
        selectWindow(originalImage);
        close();
    }
    
    if (isOpen(titulo_seg)) {
        selectWindow(titulo_seg);
        close();
    }
    
    // Save ROIs
    roiManager("Save", output_dir + titulo_base + "RoiSet.zip");
}

function processChannel(titulo, titulo_base, channel_config) {
    // Extract channel configuration
    active = channel_config[0];
    channel_num = channel_config[1];
    background = channel_config[2];
    max_display = channel_config[3];
    color = channel_config[4];
    suffix = channel_config[5];
    use_rolling_ball = channel_config[6];
    
    if (!active) return;
    
    // Process channel
    selectWindow(titulo);
    channel_title = titulo_base + suffix;
    merge_title = titulo_base + "_Ch" + channel_num;
    run("Duplicate...", "title='"+channel_title+"' duplicate channels="+channel_num);
    selectWindow(channel_title);
    
    // Reset rolling_bg_value for this channel
    rolling_bg_value = 0;
    rolling_bg_suffix = "";
    rolling_bg_column_name = "";
    
    // Calculate and store the rolling background mean first if needed
    if (background > 0 && use_rolling_ball) {
        calculateAndStoreRollingBackground(channel_title, channel_num);
    }
    
    // Get original image ID to ensure we return to it
    original_id = getImageID();
    
    // Apply processing
    if (background > 0) {
        if (use_rolling_ball) {
            // Apply the rolling ball background subtraction
            run("Subtract Background...", "rolling=" + background);
        } else {
            // Use traditional background subtraction
            run("Subtract...", "value=" + background);
        }
    }
    run(color);
    setMinAndMax(0, max_display);
    
    // Make sure we're still working with the processed image
    selectImage(original_id);
    
    // Save processed image for measurements
    saveAs("PNG", output_dir + channel_title);
    
    // Get the updated ID after saving
    processed_id = getImageID();
    
    // Create a duplicate for merge
    selectImage(processed_id);
    run("Duplicate...", "title='"+merge_title+"'");
    
    // Make sure we select the processed image for measurements
    selectImage(processed_id);
    
    // Clear results before measuring
    run("Clear Results");
    
    // Measure and save results
    if (roiManager("count") > 0) {
        print("Measuring " + roiManager("count") + " ROIs on " + channel_title);
        roiManager("Measure");
        
        // If we calculated a rolling background value, add it to each ROI
        if (rolling_bg_value > 0) {
            // Use a consistent column name format
            rolling_bg_column = rolling_bg_suffix + "_Mean_rolling_background";
            
            for (i = 0; i < nResults; i++) {
                setResult(rolling_bg_column, i, rolling_bg_value);
            }
            updateResults();
            print("Debug - Added rolling background values to column: " + rolling_bg_column);
        }
        
        saveAs("Results", output_dir + channel_title + "_table.csv");
        run("Clear Results");
    }
}

function createMerge(titulo, titulo_base) {
    // Identify which channels to merge
    activeChannels = newArray(0);
    channelColors = newArray(0);
    
    // Add bounds checking for array access
    for (i=0; i<merge_channels.length && i<num_channels; i++) {
        if (merge_channels[i] && channel_active[i]) {
            activeChannels = Array.concat(activeChannels, i+1);
            channelColors = Array.concat(channelColors, channel_colors[i]);
        }
    }
    
    print("Debug - Active channels for merge: " + activeChannels.length);
    
    // Make sure all windows are actually available before merging
    allWindowsAvailable = true;
    imageWindows = newArray(activeChannels.length);
    
    for (i=0; i<activeChannels.length; i++) {
        channelNum = activeChannels[i];
        windowName = titulo_base + "_Ch" + channelNum;
        imageWindows[i] = windowName;
        
        // Check if window exists
        windowFound = false;
        windowList = getList("image.titles");
        for (w=0; w<windowList.length; w++) {
            if (windowList[w] == windowName) {
                windowFound = true;
                break;
            }
        }
        
        if (!windowFound) {
            print("Warning: Window '" + windowName + "' not found. Cannot perform merge.");
            allWindowsAvailable = false;
            break;
        }
    }
    
    // If all windows are available, perform the merge
    if (allWindowsAvailable && activeChannels.length > 0) {
        // Set up the merge command
        mergeString = "";
        
        // We need to duplicate the windows with proper names for the merge command
        // The merge command expects c1, c2, c3, etc.
        dupWindows = newArray(activeChannels.length);
        
        // Create channels with appropriate names for merging
        for (i=0; i<activeChannels.length; i++) {
            // Select the original window
            selectWindow(imageWindows[i]);
            
            // Get the channel number
            channelNum = activeChannels[i];
            
            // Get bit depth of the image
            bd = bitDepth();
            print("Debug - Channel " + channelNum + " bit depth: " + bd);
            
            // Apply the appropriate display settings
            max_value = channel_max_display[channelNum-1];
            
            // Create a duplicate with proper channel naming for merging
            dupName = "c" + (i+1) + "-" + titulo_base;
            run("Duplicate...", "title=["+dupName+"]");
            dupWindows[i] = dupName;
            
            // Apply the display settings to the duplicated channel
            selectWindow(dupName);
            
            // Apply the correct LUT
            run(channelColors[i]);
            
            // Apply display range explicitly
            setMinAndMax(0, max_value);
            print("Debug - Applied setMinAndMax(0, " + max_value + ") to channel " + channelNum);
            
            // Add to the merge string
            if (i > 0) mergeString = mergeString + " ";
            
            // Convert the color name to single character code for Merge Channels
            colorCode = "c1"; // Default to cyan
            colorName = channelColors[i];
            
            if (colorName == "Red") colorCode = "c1";
            else if (colorName == "Green") colorCode = "c2";
            else if (colorName == "Blue") colorCode = "c3";
            else if (colorName == "Gray" || colorName == "Grays") colorCode = "c4";
            else if (colorName == "Cyan" || colorName == "cyan Zeiss") colorCode = "c5";
            else if (colorName == "Magenta") colorCode = "c6";
            else if (colorName == "Yellow") colorCode = "c7";
            
            mergeString = mergeString + colorCode + "=[" + dupName + "]";
        }
        
        // Add create parameter to create composite
        mergeString = mergeString + " create";
        
        // Run the merge channels command
        run("Merge Channels...", mergeString);
        
        // The result is automatically named "RGB" or "Composite"
        mergeResult = getTitle();
        
        // For Composite result, ensure display settings are properly applied to all channels
        if (matches(mergeResult, ".*Composite.*")) {
            print("Debug - Result is a Composite image, ensuring display settings are applied");
            
            // Loop through channels in the composite
            for (i=0; i<activeChannels.length; i++) {
                channelNum = activeChannels[i];
                Stack.setChannel(i+1);
                setMinAndMax(0, channel_max_display[channelNum-1]);
                print("Debug - Applied display range to composite channel " + (i+1));
            }
        }
        
        // Save the merged image
        saveAs("PNG", output_dir + titulo_base + "_merge");
        savedName = getTitle();
        
        // Close the merged image
        close();
        
        // Close all the duplicated channel windows
        for (i=0; i<dupWindows.length; i++) {
            // Check if the window is still open before trying to close it
            windowIsOpen = false;
            windowList = getList("image.titles");
            for (w=0; w<windowList.length; w++) {
                if (windowList[w] == dupWindows[i]) {
                    windowIsOpen = true;
                    break;
                }
            }
            
            if (windowIsOpen) {
                selectWindow(dupWindows[i]);
                close();
            }
        }
        
        print("Successfully created merged image");
    } else {
        showMessage("Error", "Not all channels are available for merging. Check the Log window for details.");
    }
}

function arraySum(arr) {
    sum = 0;
    for (i=0; i<arr.length; i++) {
        if (arr[i] == true) sum++;
    }
    return sum;
}

// Function to save parameters to a text file
function saveParametersToFile(output_dir) {
    // Get current date and time
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    date_str = "" + year + "-" + IJ.pad((month+1), 2) + "-" + IJ.pad(dayOfMonth, 2);
    time_str = "" + IJ.pad(hour, 2) + ":" + IJ.pad(minute, 2) + ":" + IJ.pad(second, 2);
    
    // Create file for parameters
    file_path = output_dir + "analysis_parameters.txt";
    
    // Use the append method directly instead of open/close
    File.append("=== Multi-Channel Analysis Parameters ===", file_path);
    File.append("Generated on: " + date_str + " at " + time_str, file_path);
    File.append("Number of channels configured: " + num_channels, file_path);
    File.append("", file_path);
    
    // Channel settings
    File.append("=== CHANNEL SETTINGS ===", file_path);
    for (i=0; i<4; i++) {
        if (channel_active[i]) {
            status = "ACTIVE";
        } else {
            status = "inactive";
        }
        
        File.append("Channel " + (i+1) + ": " + status, file_path);
        
        if (channel_active[i]) {
            File.append("  Background: " + channel_background[i], file_path);
            rolling_method_text = "No";
            if (channel_use_rolling_ball[i]) {
                rolling_method_text = "Yes";
            }
            File.append("  Use Rolling Ball Method: " + rolling_method_text, file_path);
            File.append("  Max Display: " + channel_max_display[i], file_path);
            File.append("  Color: " + channel_colors[i], file_path);
            File.append("  Suffix: " + channel_suffixes[i], file_path);
            
            // Indicate if this channel is used for segmentation
            if ((i+1) == segmentation_channel) {
                File.append("  ** Used for segmentation **", file_path);
            }
            
            // Indicate if this channel is included in merge
            if (merge_channels[i] == true) {
                File.append("  ** Included in merge **", file_path);
            }
        }
        File.append("", file_path);
    }
    
    // Segmentation settings
    File.append("=== SEGMENTATION SETTINGS ===", file_path);
    File.append("Segmentation Channel: " + segmentation_channel, file_path);
    File.append("StarDist Model: " + stardist_model, file_path);
    File.append("Probability Threshold: " + prob_thresh, file_path);
    File.append("NMS Threshold: " + nms_thresh, file_path);
    File.append("Exclude Boundary: " + exclude_boundary, file_path);
    
    // No need to close the file - File.append handles that automatically
    print("Parameters saved to: " + file_path);
}

// Function to create a combined CSV with measurements from all channels
function createCombinedMeasurements(titulo_base, output_dir) {
    // Initialize arrays to store data from each channel
    channelData = newArray(4);
    channelHeaders = newArray(4);
    activeChannelCount = 0;
    
    // Get original image filename with extension
    imageFilename = titulo_base + ".tif";  // Changed from .czi to .tif as default
    
    // Define which measurements are intensity-related and should have channel prefixes
    // All other measurements are considered shape-related and will appear only once
    intensityMeasurements = newArray("Mean", "StdDev", "Mode", "Min", "Max", "IntDen", "RawIntDen", "Median", "Mean_rolling_background");
    
    // Read data from individual channel CSVs
    for (i=0; i<4; i++) {
        if (channel_active[i]) {
            suffix = channel_suffixes[i];
            csvPath = output_dir + titulo_base + suffix + "_table.csv";
            
            // Check if the CSV file exists
            if (File.exists(csvPath)) {
                // Read the entire file content
                channelData[i] = File.openAsString(csvPath);
                
                // Extract lines from the file
                lines = split(channelData[i], "\n");
                
                // If we have at least a header line
                if (lines.length > 0) {
                    channelHeaders[i] = lines[0];
                    activeChannelCount++;
                    print("Found data for Channel " + (i+1) + " with " + (lines.length-1) + " rows");
                }
            } else {
                print("Warning: CSV file not found for Channel " + (i+1) + ": " + csvPath);
            }
        }
    }
    
    // If we have data, create combined CSV
    if (activeChannelCount > 0) {
        // Create output file path
        combinedCsvPath = output_dir + titulo_base + "_allChannels.csv";
        
        // Get ROI count from one of the files
        roiCount = roiManager("count");
        print("ROI count: " + roiCount);
        
        // Start with empty content
        fullContent = "";
        
        // Create the header line starting with ROI and ImageID 
        headerLine = "ROI,ImageID";
        
        // First collect all shape measurements
        shapeColumnsAdded = newArray();
        
        // Collect all shape headers first
        for (i=0; i<4; i++) {
            if (channel_active[i] && channelHeaders[i] != "") {
                // Get header line and skip the first element (which is empty or ROI label)
                header = channelHeaders[i];
                headerParts = split(header, ",");
                
                // Add each shape measurement header (non-intensity)
                for (h=1; h<headerParts.length; h++) {  // Start at 1 to skip the first column
                    label = headerParts[h];
                    if (label != "") {
                        // Check if this is NOT an intensity measurement
                        isIntensityMeasurement = false;
                        for (im=0; im<intensityMeasurements.length; im++) {
                            if (label == intensityMeasurements[im]) {
                                isIntensityMeasurement = true;
                                break;
                            }
                        }
                        
                        // Only process shape measurements in this first pass
                        if (!isIntensityMeasurement) {
                            // For shape measurements, only add once
                            shapeAlreadyAdded = false;
                            for (s=0; s<shapeColumnsAdded.length; s++) {
                                if (shapeColumnsAdded[s] == label) {
                                    shapeAlreadyAdded = true;
                                    break;
                                }
                            }
                            
                            if (!shapeAlreadyAdded) {
                                headerLine = headerLine + "," + label;
                                shapeColumnsAdded = Array.concat(shapeColumnsAdded, label);
                            }
                        }
                    }
                }
            }
        }
        
        // Now collect all intensity-related measurements with their channel prefixes
        intensityHeaderParts = newArray();
        intensityChannelIndices = newArray();
        intensityMeasurementIndices = newArray();
        
        // Now add all intensity measurements
        for (i=0; i<4; i++) {
            if (channel_active[i] && channelHeaders[i] != "") {
                // Get header line and skip the first element
                header = channelHeaders[i];
                headerParts = split(header, ",");
                
                // Get the appropriate prefix for this channel
                channelPrefix = channel_suffixes[i];
                if (startsWith(channelPrefix, "_")) {
                    channelPrefix = substring(channelPrefix, 1);
                }
                
                // If channelPrefix is empty, use Ch# as fallback
                if (channelPrefix == "") {
                    channelPrefix = "Ch" + (i+1);
                }
                
                // Add each intensity measurement header
                for (h=1; h<headerParts.length; h++) {
                    label = headerParts[h];
                    if (label != "") {
                        // Check if this is an intensity measurement
                        isIntensityMeasurement = false;
                        for (im=0; im<intensityMeasurements.length; im++) {
                            if (label == intensityMeasurements[im]) {
                                isIntensityMeasurement = true;
                                break;
                            }
                        }
                        
                        if (isIntensityMeasurement) {
                            // Skip if this is a Mean_rolling_background column - we'll handle those separately
                            if (label == "Mean_rolling_background") {
                                continue;
                            }
                            
                            // Add to the header
                            headerLine = headerLine + "," + channelPrefix + "_" + label;
                            
                            // Store the info for this measurement
                            intensityHeaderParts = Array.concat(intensityHeaderParts, channelPrefix + "_" + label);
                            intensityChannelIndices = Array.concat(intensityChannelIndices, i);
                            intensityMeasurementIndices = Array.concat(intensityMeasurementIndices, h);
                        }
                    }
                }
                
                // If this channel uses rolling ball method, make sure we include the background column
                if (channel_use_rolling_ball[i] && channel_background[i] > 0) {
                    // Use consistent naming for the rolling background column
                    rolling_bg_column = channelPrefix + "_Mean_rolling_background";
                    
                    // Find if this column already exists in headers
                    rolling_bg_exists = false;
                    
                    // First check in the current header parts
                    for (h=1; h<headerParts.length; h++) {
                        // Check for both possible formats to avoid duplicates
                        if (headerParts[h] == "Mean_rolling_background" || 
                            headerParts[h] == rolling_bg_column) {
                            rolling_bg_exists = true;
                            break;
                        }
                    }
                    
                    // If not in headers, add it explicitly
                    if (!rolling_bg_exists) {
                        headerLine = headerLine + "," + rolling_bg_column;
                        intensityHeaderParts = Array.concat(intensityHeaderParts, rolling_bg_column);
                        intensityChannelIndices = Array.concat(intensityChannelIndices, i);
                        intensityMeasurementIndices = Array.concat(intensityMeasurementIndices, -1); // -1 indicates special handling
                    }
                }
            }
        }
        
        // Add header to content
        fullContent = headerLine + "\n";
        
        // Add each ROI's data
        for (roi=0; roi<roiCount; roi++) {
            // Start line with ROI number and ImageID
            line = "" + (roi+1) + "," + imageFilename;
            
            // First add all shape measurements
            // Track which shape measurements have been added for this ROI
            shapeValuesAdded = newArray(shapeColumnsAdded.length);
            for (s=0; s<shapeValuesAdded.length; s++) {
                shapeValuesAdded[s] = false;
            }
            
            // First pass to add all shape measurements
            for (i=0; i<4; i++) {
                if (channel_active[i] && channelData[i] != "") {
                    csvLines = split(channelData[i], "\n");
                    
                    // Make sure we have enough lines in this channel's data
                    if (csvLines.length > roi+1) {  // +1 because first line is header
                        rowData = csvLines[roi+1];
                        rowParts = split(rowData, ",");
                        
                        // Get header parts for reference
                        headerParts = split(channelHeaders[i], ",");
                        
                        // Add shape measurements first
                        for (v=1; v<rowParts.length && v<headerParts.length; v++) {
                            label = headerParts[v];
                            
                            // Check if this is NOT an intensity measurement
                            isIntensityMeasurement = false;
                            for (im=0; im<intensityMeasurements.length; im++) {
                                if (label == intensityMeasurements[im]) {
                                    isIntensityMeasurement = true;
                                    break;
                                }
                            }
                            
                            // For shape measurements only
                            if (!isIntensityMeasurement) {
                                // Find the index in shapeColumnsAdded
                                shapeIndex = -1;
                                for (s=0; s<shapeColumnsAdded.length; s++) {
                                    if (shapeColumnsAdded[s] == label) {
                                        shapeIndex = s;
                                        break;
                                    }
                                }
                                
                                // Only add if not already added
                                if (shapeIndex >= 0 && !shapeValuesAdded[shapeIndex]) {
                                    line = line + "," + rowParts[v];
                                    shapeValuesAdded[shapeIndex] = true;
                                }
                            }
                        }
                    }
                }
            }
            
            // Now add all intensity measurements in the same order as the headers
            for (idx=0; idx<intensityHeaderParts.length; idx++) {
                chanIndex = intensityChannelIndices[idx];
                measIndex = intensityMeasurementIndices[idx];
                
                // Handle special case for rolling background
                if (measIndex == -1) {
                    // This is a rolling background column
                    if (channel_use_rolling_ball[chanIndex] && channel_background[chanIndex] > 0) {
                        // For rolling background, all ROIs in the same image have the same value
                        // Get the channel suffix for the column name
                        channel_suffix = channel_suffixes[chanIndex];
                        if (startsWith(channel_suffix, "_")) {
                            channel_suffix = substring(channel_suffix, 1);
                        }
                        
                        // If channel suffix is empty, use Ch# as fallback
                        if (channel_suffix == "") {
                            channel_suffix = "Ch" + (chanIndex+1);
                        }
                        
                        // Use the consistent column naming format
                        rolling_bg_column = channel_suffix + "_Mean_rolling_background";
                        
                        // Look for the rolling background in any row
                        csvLines = split(channelData[chanIndex], "\n");
                        if (csvLines.length > 1) {
                            // Get the header to find which column has our value
                            headerLine = csvLines[0];
                            headerParts = split(headerLine, ",");
                            
                            // Get a row's data
                            rowData = csvLines[1];
                            rowParts = split(rowData, ",");
                            
                            // Search for the rolling background value in the header
                            rollingBgValue = "";
                            for (v=1; v<headerParts.length && v<rowParts.length; v++) {
                                // Check for both possible formats of the column name
                                if (headerParts[v] == "Mean_rolling_background" || 
                                    headerParts[v] == rolling_bg_column) {
                                    rollingBgValue = rowParts[v];
                                    break;
                                }
                            }
                            
                            if (rollingBgValue != "") {
                                line = line + "," + rollingBgValue;
                            } else {
                                line = line + ",";
                            }
                        } else {
                            line = line + ",";
                        }
                    } else {
                        line = line + ",";
                    }
                } else {
                    // Regular intensity measurement
                    // Get the data for this measurement
                    if (channel_active[chanIndex] && channelData[chanIndex] != "") {
                        csvLines = split(channelData[chanIndex], "\n");
                        
                        // Make sure we have enough lines in this channel's data
                        if (csvLines.length > roi+1) {  // +1 because first line is header
                            rowData = csvLines[roi+1];
                            rowParts = split(rowData, ",");
                            
                            // Add this intensity measurement if it exists
                            if (measIndex < rowParts.length) {
                                line = line + "," + rowParts[measIndex];
                            } else {
                                // No data for this measurement
                                line = line + ",";
                            }
                        } else {
                            // No data for this ROI
                            line = line + ",";
                        }
                    } else {
                        // Channel not active
                        line = line + ",";
                    }
                }
            }
            
            // Add this ROI's line to the full content
            fullContent = fullContent + line + "\n";
        }
        
        // Save the combined data to CSV
        File.saveString(fullContent, combinedCsvPath);
        print("Created combined measurements file: " + combinedCsvPath);
    } else {
        print("Warning: No active channels found with measurement data");
    }
}

// Function to create a single CSV file by concatenating all _allChannels.csv files
function generateCompleteDataFile(output_dir) {
    print("----------------------------");
    print("Generating complete data file...");
    
    // Get list of all files in output directory
    output_files = getFileList(output_dir);
    
    // Find all _allChannels.csv files
    allChannelsFiles = newArray(0);
    for (i=0; i<output_files.length; i++) {
        if (endsWith(output_files[i], "_allChannels.csv")) {
            allChannelsFiles = Array.concat(allChannelsFiles, output_files[i]);
        }
    }
    
    print("Found " + allChannelsFiles.length + " individual data files");
    
    // If we have at least one file, create the complete data file
    if (allChannelsFiles.length > 0) {
        // Path for the complete data file
        completeDataPath = output_dir + "Complete_data.csv";
        
        // Variable to store the complete file content
        completeContent = "";
        
        // Add header from the first file (only once)
        firstFilePath = output_dir + allChannelsFiles[0];
        firstFileContent = File.openAsString(firstFilePath);
        firstFileLines = split(firstFileContent, "\n");
        
        if (firstFileLines.length > 0) {
            // Add header line
            completeContent = firstFileLines[0] + "\n";
            
            // Process all files
            for (i=0; i<allChannelsFiles.length; i++) {
                filePath = output_dir + allChannelsFiles[i];
                fileContent = File.openAsString(filePath);
                fileLines = split(fileContent, "\n");
                
                // Skip the header line, start from line 1
                for (j=1; j<fileLines.length; j++) {
                    if (fileLines[j].length > 0) {
                        completeContent = completeContent + fileLines[j] + "\n";
                    }
                }
                
                print("Added data from " + allChannelsFiles[i]);
            }
            
            // Save the complete data to CSV
            File.saveString(completeContent, completeDataPath);
            print("Created complete data file: " + completeDataPath);
        } else {
            print("Error: First file has no content");
        }
    } else {
        print("No _allChannels.csv files found in the output directory");
    }
}

// Function to calculate and store rolling background mean
function calculateAndStoreRollingBackground(channel_title, channel_num) {
    // Get the channel suffix for column naming
    channel_suffix = channel_suffixes[channel_num-1];
    if (startsWith(channel_suffix, "_")) {
        channel_suffix = substring(channel_suffix, 1);
    }
    
    // If channel suffix is empty, use Ch# as fallback
    if (channel_suffix == "") {
        channel_suffix = "Ch" + channel_num;
    }
    
    // Backup current Results
    if (nResults > 0) {
        results_backup = newArray(nResults);
        for (i = 0; i < nResults; i++) {
            results_backup[i] = getResult("Mean", i);
        }
    } else {
        results_backup = newArray(0);
    }
    
    // Make sure we're working with the original channel window first
    selectWindow(channel_title);
    
    // Create a temporary duplicate of the image for background calculation
    temp_title = "temp_for_bg_" + random();
    run("Duplicate...", "title='"+temp_title+"'");
    selectWindow(temp_title);
    
    // Apply rolling ball background subtraction with create option to generate background
    background = channel_background[channel_num-1];
    run("Subtract Background...", "rolling=" + background + " create");
    
    // The background image will be the most recently created window
    background_title = getTitle();
    print("Debug - Background image title: " + background_title);
    
    // Ensure we're measuring the entire background image
    selectWindow(background_title);
    run("Select All");
    
    // Clear results before measuring
    run("Clear Results");
    
    // Calculate mean of background
    run("Measure");
    background_mean = getResult("Mean", 0);
    print("Debug - Background mean value: " + background_mean);
    
    // Close the background image
    close(background_title);
    
    // Try to close the temporary image if it's still open
    if (isOpen(temp_title)) {
        selectWindow(temp_title);
        close();
    }
    
    // Return to the original channel window
    selectWindow(channel_title);
    
    // Clear the temporary results
    run("Clear Results");
    
    // Restore original Results if there were any
    if (results_backup.length > 0) {
        for (i = 0; i < results_backup.length; i++) {
            setResult("Mean", i, results_backup[i]);
        }
        updateResults();
    }
    
    // Store the rolling background value as a global variable for later use
    rolling_bg_value = background_mean;
    
    // Store the suffix for later reference
    rolling_bg_suffix = channel_suffix;
    
    // Use a standard column name format for consistency across all functions
    rolling_bg_column_name = channel_suffix + "_Mean_rolling_background";
    
    print("Debug - Stored background mean: " + background_mean + " for later use with column " + rolling_bg_column_name);
    
    return background_mean;
}