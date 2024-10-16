macro "Auto drift-correction" {

    //to retain the metadata        
    info = getMetadata("info");
    gain = getInfo("Multiplication Gain");
    exposure = getInfo("Exposure");
    exposure_time = "";
    getPixelSize(unit, pixelWidth, pixelHeight);
    if (exposure != "")
        exposure_time = substring(exposure, 0, 3);

    getDimensions(width, height, channels, slices, frames);

    interval = getInfo("Frame interval (s)");

    while (true) {
        Dialog.create("Drift Settings");
        Dialog.addNumber("Gaussian fit SD", "0.8");
        Dialog.addNumber("EM-Gain", gain);
        Dialog.addNumber("Exposure time", exposure_time);
        Dialog.addNumber("Scale (" + unit + ")", pixelWidth);
        Dialog.addCheckbox("Video processing*", false);
        Dialog.addCheckbox("Save as TIF", true);
        Dialog.addCheckbox("Operate for large stacks", false);
        Dialog.addCheckbox("Apply to all stacks in this directory", false);
        Dialog.addCheckbox("Show drifted coordinate", false);
        Dialog.addChoice("Choose the primary channel for drift correction:", newArray("1", "2", "3", "4"));
        Dialog.addChoice("Storage location", newArray("Default", "Let me select"));
        Dialog.addMessage("* Video processing includes background substraction,\n adding scale bar, adding time stamp and saving as avi file", 12, "Red");
        Dialog.show();

        //obtain parameters from dialog
        Gs_SD = Dialog.getNumber();
        gain = Dialog.getNumber();
        exposure_time = Dialog.getNumber();
        pixelWidth = Dialog.getNumber();
        video_processing = Dialog.getCheckbox();
        Save_as_tiff = Dialog.getCheckbox();
        Big_tif = Dialog.getCheckbox();
        all_stacks = Dialog.getCheckbox();
        drft_show = Dialog.getCheckbox();
        Pchannel = Dialog.getChoice();
        storage = Dialog.getChoice();

        /////////////////////////////////

        img_directory = getDirectory("image");
        parent_folder_name = File.getName(img_directory);
        if (storage == "Let me select") {
            new_img_directory = getDirectory("Where do you want to store the drift corrected data");

            drift_folder = new_img_directory + parent_folder_name + "_drift_corrected" ;
            drift_data_folder = drift_folder + File.separator + "drift_data" ;
            temp_folder = new_img_directory + File.separator + "Temp";
        } else {
            drift_folder = img_directory + parent_folder_name + "_drift_corrected" ;
            drift_data_folder = drift_folder + File.separator + "drift_data" ;
            temp_folder = img_directory + File.separator + "Temp";
        }

        if (all_stacks) {
            file_list = getFileList(img_directory);
            D_corrected_tifs = getFileList(drift_folder);

            //Remove the already drift corrected files from the list
            for (i = 0; i < D_corrected_tifs.length; i++) {
                file_list = Array.deleteValue(file_list, D_corrected_tifs[i]);
            }

            tif_list = newArray();
            k = 0;
            for (i = 0; i < file_list.length; i++) {
                if (endsWith(file_list[i], ".tif")) {
                    tif_list[k] = file_list[i];
                    k++;
                }
            }

            while (tif_list.length > 0) {
                temp_title = getTitle();
                if (correct_drift(Gs_SD, drft_show, video_processing, Save_as_tiff, Big_tif, Pchannel)) {
                    tif_list = Array.deleteValue(tif_list, temp_title);
                    close(temp_title);
                    if (tif_list.length > 0) {
                        open(img_directory + File.separator + tif_list[0]);
                    }
                } else {
                    // Fitting failed, show error message and break out of the loop
                    showMessage("Fitting failed with the current parameters. Please try different values.");
                    break;
                }
            }
        } else {
            if (correct_drift(Gs_SD, drft_show, video_processing, Save_as_tiff, Big_tif, Pchannel)) {
                break; // Fitting successful, exit the loop
            } else {
                showMessage("Fitting failed with the current parameters. Please try different values.");
            }
        }

        if (all_stacks) {
            if (k == 0)
                print(" It seems these stacks are already drift-corrected.\n If you want to do drift correction anyways, you have to delete existing files in:\n " + drift_folder + "\n");
            print(k + " stacks were corrected for drifts. The drift-corrected stacks are stored at:\n" + drift_folder);
        }
    }
}

function correct_drift(Gs_SD, drft_show, video_processing, Save_as_tiff, Big_tif, Pchannel) {
    // function description
    getDimensions(width, height, channels, slices, frames);
    info = getMetadata("info");
    getPixelSize(unit, pixelWidth, pixelHeight);
    pixelwidth = pixelWidth * 1000;

    if (drft_show) {
        plot_drift = "plot_drift";
    } else {
        plot_drift = "";
    }

    ori_img_name = getTitle();

    if (channels > 1) {
        run("Split Channels");
        selectWindow("C" + Pchannel + "-" + ori_img_name);
    }

    img_name = getTitle();

    File.makeDirectory(drift_folder);
    File.makeDirectory(drift_data_folder);
    File.makeDirectory(temp_folder);
    img_name_raw = split(img_name, ".");
    drift_file = drift_data_folder + File.separator + img_name_raw[0] + ".tsv";

    if (channels > 1)
        Big_tif = false;

    if (Big_tif) {
        for (i = 1; i <= channels; i++) {
            selectWindow("C" + i + "-" + ori_img_name);
            setMetadata("Info", info);
            if (i != Pchannel) {
                saveAs("Tiff", "[" +temp_folder + File.separator + "C" + i + "-" + ori_img_name + "]");
                close("C" + i + "-" + ori_img_name);
            }
        }
    }

    if (channels > 1) {
        selectWindow(img_name);
    }

    run("Simple Fit", "  camera_type=EMCCD calibration=" + pixelwidth + " camera_bias=1 gain=" + gain + " exposure_time=" + exposure_time + " gaussian_sd=" + Gs_SD + "");

	logText = getInfo("log");
	inlog = indexOf(logText, "0 localisations") ;
	print(inlog) ;
while (inlog != -1) {

    close("Results");
    close("Fit Results");
    close("Log");
    gain = gain - 5;
    exposure_time = exposure_time - 5 ;
    Gs_SD = 0.5 + random()*2 ;
    if(gain <= 0){
    	gain = 5 + random()*200 ;
    	inlog = -1;
    	return false;

    }
        if(exposure_time <= 0){
    	exposure_time = 5 + random()*200 ;
    	inlog = -1;
		return false;
    }
    run("Simple Fit", "  camera_type=EMCCD calibration=" + pixelwidth + " camera_bias=1 gain=" + gain + " exposure_time=" + exposure_time + " gaussian_sd=" + Gs_SD + "");
	if(inlog != -1){
	logText = getInfo("log");
	inlog = indexOf(logText, "0 localisations") ;
	}
}

    close("Results");
    close("Fit Results");
    close("Log");

    run("Drift Calculator", "input=[" + img_name + " (LVM LSE)] method=[Reference Stack Alignment] max_iterations=50 relative_error=0.010 smoothing=0.25 limit_smoothing min_smoothing_points=10 max_smoothing_points=50 smoothing_iterations=1 " + plot_drift + " stack_image=[" + img_name + "] start_frame=1 frame_spacing=1 interpolation_method=Bicubic update_method=Update save_drift drift_file=[" + drift_file + "]" );

    if (Big_tif) {
        saveAs("Tiff", temp_folder + File.separator + "C" + Pchannel + "-" + ori_img_name);
        close("C" + Pchannel + "-" + ori_img_name);}
    requires("1.35r");
lineseparator = "\n";
cellseparator = "\t";

// copies the whole RT to an array of lines
lines = split(File.openAsString(drift_file), lineseparator);

// recreates the columns headers
labels = split(lines[0], cellseparator);
if (labels[0] == " ")
    k = 1; // it is an ImageJ Results table, skip first column
else
    k = 0; // it is not a Results table, load all columns
for (j = k; j < labels.length; j++)
    setResult(labels[j], 0, 0);

// dispatches the data into the new RT
run("Clear Results");
for (i = 1; i < lines.length; i++) {
    items = split(lines[i], cellseparator);
    for (j = k; j < items.length; j++)
        setResult(labels[j], i - 1, items[j]);
}
updateResults();

dash = substring(img_name, 2, 3);
C = substring(img_name, 0, 1);
if (dash == "-" && C == "C") {
    ori_img_name = substring(img_name, 3);
}

img_titles = newArray();
Two_ch_colors = newArray("Magenta", "Cyan");
three_ch_colors = newArray("Magenta", "Yellow", "Cyan");
// Apply drift

for (j = 1; j <= channels; j++) {
    if (channels == 1) {
        temp_img_name = ori_img_name;
    } else {
        temp_img_name = "C" + j + "-" + ori_img_name;
    }
    if (isOpen(temp_img_name) == false) {
        open(temp_folder + File.separator + "C" + j + "-" + ori_img_name);
    }
    selectWindow(temp_img_name);
    run("Enhance Contrast", "saturated=0.35");
    img_titles[j - 1] = "C" + j + "-" + ori_img_name;
    N_of_rsults = nResults;
    for (i = 0; i < N_of_rsults; i++) {
        dx = getResult("X", i);
        if (dx == NaN){
        	dxStr = getResultString("X", i);
        	dxStr = replace(dx, ",", ".");
        	dx = parseFloat(dxStr);
        }
        dy = getResult("Y", i);
        if (dy == NaN){
        	dyStr = getResultString("Y", i);
        	dyStr = replace(dx, ",", ".");
        	dy = parseFloat(dyStr);
        }
        makeRectangle(0, 0, width + dx, height + dy);
        setSlice(i + 1);
        run("Translate...", "x=dx y=dy interpolation=Bicubic");
    }
    run("Crop");

    if (Big_tif) {
        saveAs("Tiff", temp_folder + File.separator + "C" + j + "-" + ori_img_name);
        close("C" + j + "-" + ori_img_name);
    }
}

if (Big_tif) {
    for (j = 1; j <= channels; j++) {
        open(temp_folder + File.separator + "C" + j + "-" + ori_img_name);
    }
}

if (channels == 2) {
    run("Merge Channels...", "c1=" + img_titles[0] + " c2=" + img_titles[1] + " create ignore  ");
}
if (channels == 3) {
    run("Merge Channels...", "c1=" + img_titles[0] + " c2=" + img_titles[1] + " c3=" + img_titles[2] + " create ignore ");
}

selectWindow(ori_img_name);
info = info + "\n" + "Directory=" + img_directory;
setMetadata("Info", info);
close("Log");
close("Results");
if (video_processing) {
    runMacro("MakeVideos.ijm");
}

if (Save_as_tiff) {
    saveAs("Tiff", drift_folder + ori_img_name);
}

if (Big_tif) {
    for (j = 1; j <= channels; j++) {
        File.delete(temp_folder + File.separator + "C" + j + "-" + ori_img_name);
    }
}
File.delete(temp_folder);
close("Log");
return true; // Fitting successful
}
