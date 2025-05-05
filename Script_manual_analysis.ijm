// Multi-channel Fluorescence Image Analysis Macro
// Author: Ariel Waisman
// Description: Analyzes multi-channel fluorescence images with configurable parameters

// ---- CONFIGURATION SECTION ----

// Channel Configuration Arrays
// Format for each channel: [active, channel_number, background, max_display, color, suffix]
var channel1 = newArray(true, 1, 0, 90, "Cyan", "_DAPI");     // DAPI
var channel2 = newArray(true, 2, 0, 255, "Green", "_Nanog");  // Oct6
var channel3 = newArray(true, 3, 0, 160, "Magenta", "_Oct6-mCherry"); // mCerulean
var channel4 = newArray(false, 4, 500, 3500, "Red", "_Other");  // Other

// Merge Configuration
var merge_channels = newArray(false, true, true, false); // Which channels to include in merge

// Segmentation Configuration
var segmentation_channel = 1; // Which channel to use for nuclear segmentation (usually DAPI)
var stardist_model = "Versatile (fluorescent nuclei)"; // StarDist model choice

// StarDist Parameters
var prob_thresh = 0.5;
var nms_thresh = 0.4;
var exclude_boundary = 2;

// ---- MAIN SCRIPT ----

run("Close All");
//setBatchMode(true);

// Record start time
getDateAndTime(start_year, start_month, start_dayOfWeek, start_dayOfMonth, start_hour, start_minute, start_second, start_msec);
start_time = start_hour * 3600 + start_minute * 60 + start_second;
print("Starting analysis at: " + IJ.pad(start_hour, 2) + ":" + IJ.pad(start_minute, 2) + ":" + IJ.pad(start_second, 2));

// Select input directory
dir = getDirectory("Choose input directory");
list = getFileList(dir);

// Create output directory
output_dir = dir + "analysis" + File.separator;
File.makeDirectory(output_dir);

// Save configuration to a log file
saveConfigToFile(output_dir);

// Process each file
fileCount = 0;
for (i=0; i<list.length; i++) {
    // Support both .tif and .czi files
    if (matches(list[i], ".*\\.(tif|tiff|czi)$")) {
        processFile(dir, list[i], output_dir);
        fileCount++;
    }
}

// Record end time and calculate duration
getDateAndTime(end_year, end_month, end_dayOfWeek, end_dayOfMonth, end_hour, end_minute, end_second, end_msec);
end_time = end_hour * 3600 + end_minute * 60 + end_second;
execution_time = end_time - start_time;
hours = floor(execution_time / 3600);
minutes = floor((execution_time % 3600) / 60);
seconds = execution_time % 60;
time_str = IJ.pad(hours, 2) + ":" + IJ.pad(minutes, 2) + ":" + IJ.pad(seconds, 2);

// Print completion message to log
print("----------------------------");
print("Analysis complete!");
print("Processed " + fileCount + " files in " + time_str + " (HH:MM:SS)");
print("Results saved to: " + output_dir);

// Update the configuration file with execution time
appendExecutionInfo(output_dir, fileCount, time_str);

// Show completion message
showMessage("Analysis Complete", "Processed " + fileCount + " files in " + time_str + "\n\nResults saved to:\n" + output_dir);

// ---- FUNCTIONS ----

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
        // Use direct file opening for TIF files
        open(path);
    }
    
    // Get base filename
    titulo = getTitle();
    titulo_base = replace(titulo, "\\.(czi|tif|tiff)$", "");
    
    // Process segmentation channel first
    if (segmentation_channel > 0) {
        processSegmentationChannel(titulo, titulo_base, segmentation_channel);
    }
    
    // Process each active channel
    if (channel1[0]) processChannel(titulo, titulo_base, channel1);
    if (channel2[0]) processChannel(titulo, titulo_base, channel2);
    if (channel3[0]) processChannel(titulo, titulo_base, channel3);
    if (channel4[0]) processChannel(titulo, titulo_base, channel4);
    
    // Create merge if needed
    if (arraySum(merge_channels) > 0) {
        createMerge(titulo, titulo_base);
    }
    
    run("Close All");
}

function processSegmentationChannel(titulo, titulo_base, channel_num) {
    // Duplicate segmentation channel
    selectWindow(titulo);
    titulo_seg = titulo_base + "_segmentation";
    run("Duplicate...", "title='"+titulo_seg+"' duplicate channels="+channel_num);
    
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
    
    // Clean up and save ROIs
    selectWindow("Label Image");
    close();
    selectWindow(titulo_seg);
    roiManager("Show All");
    run("Flatten");
    saveAs("PNG", output_dir + titulo_seg);
    close();
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
    
    if (!active) return;
    
    // Process channel
    selectWindow(titulo);
    channel_title = titulo_base + suffix;
    merge_title = titulo_base + "_Ch" + channel_num;
    run("Duplicate...", "title='"+channel_title+"' duplicate channels="+channel_num);
    selectWindow(channel_title);
    
    // Apply processing
    if (background > 0) run("Subtract...", "value="+background);
    run(color);
    setMinAndMax(0, max_display);
    
    // Save processed image for measurements
    saveAs("PNG", output_dir + channel_title);
    
    // Create a duplicate for merge
    run("Duplicate...", "title='"+merge_title+"'");
    
    // Measure and save results
    if (roiManager("count") > 0) {
        roiManager("Measure");
        saveAs("Results", output_dir + channel_title + "_table.csv");
        run("Clear Results");
    }
}

function createMerge(titulo, titulo_base) {
    selectWindow(titulo);
    merge_string = "";
    
    // Build merge string with proper channel references
    for (i=0; i<merge_channels.length; i++) {
        if (merge_channels[i]) {
            if (merge_string != "") merge_string += " ";
            merge_string += "c" + (i+1) + "=" + titulo_base + "_Ch" + (i+1);
        }
    }
    
    // Execute merge command
    if (merge_string != "") {
        run("Merge Channels...", merge_string + " create");
        saveAs("PNG", output_dir + titulo_base + "_merge");
    }
}

function arraySum(arr) {
    sum = 0;
    for (i=0; i<arr.length; i++) {
        if (arr[i]) sum++;
    }
    return sum;
}

function saveConfigToFile(output_dir) {
    // Get current date and time
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    date_str = "" + year + "-" + IJ.pad((month+1), 2) + "-" + IJ.pad(dayOfMonth, 2);
    time_str = "" + IJ.pad(hour, 2) + ":" + IJ.pad(minute, 2) + ":" + IJ.pad(second, 2);
    
    // Create file for parameters
    file_path = output_dir + "analysis_configuration.txt";
    
    // Save configuration details
    File.append("=== Multi-Channel Analysis Configuration ===", file_path);
    File.append("Generated on: " + date_str + " at " + time_str, file_path);
    File.append("", file_path);
    
    // Channel settings
    File.append("=== CHANNEL SETTINGS ===", file_path);
    
    saveChannelConfig(file_path, "Channel 1", channel1);
    saveChannelConfig(file_path, "Channel 2", channel2);
    saveChannelConfig(file_path, "Channel 3", channel3);
    saveChannelConfig(file_path, "Channel 4", channel4);
    
    // Segmentation settings
    File.append("=== SEGMENTATION SETTINGS ===", file_path);
    File.append("Segmentation Channel: " + segmentation_channel, file_path);
    File.append("StarDist Model: " + stardist_model, file_path);
    File.append("Probability Threshold: " + prob_thresh, file_path);
    File.append("NMS Threshold: " + nms_thresh, file_path);
    File.append("Exclude Boundary: " + exclude_boundary, file_path);
    
    print("Configuration saved to: " + file_path);
}

function saveChannelConfig(file_path, label, config) {
    if (config[0]) {
        status = "ACTIVE";
    } else {
        status = "inactive";
    }
    
    File.append(label + ": " + status, file_path);
    
    if (config[0]) {
        File.append("  Channel Number: " + config[1], file_path);
        File.append("  Background: " + config[2], file_path);
        File.append("  Max Display: " + config[3], file_path);
        File.append("  Color: " + config[4], file_path);
        File.append("  Suffix: " + config[5], file_path);
        
        // Indicate if this channel is used for segmentation
        if (config[1] == segmentation_channel) {
            File.append("  ** Used for segmentation **", file_path);
        }
        
        // Indicate if this channel is included in merge
        index = config[1] - 1;
        if (index >= 0 && index < merge_channels.length && merge_channels[index]) {
            File.append("  ** Included in merge **", file_path);
        }
    }
    File.append("", file_path);
}

function appendExecutionInfo(output_dir, fileCount, time_str) {
    file_path = output_dir + "analysis_configuration.txt";
    
    File.append("=== EXECUTION INFO ===", file_path);
    File.append("Total files processed: " + fileCount, file_path);
    File.append("Processing time: " + time_str + " (HH:MM:SS)", file_path);
    File.append("Analysis complete!", file_path);
}