///////////////////////////////////////////////////////////////////////////////
//
// This class configures and manages the connection to Lab Streaming Layer.
// LSL input enables OpenBCI to take input from a remote OpenBCI, or other
// kinds of hardware
//
// Created: Adam Feuer, 2019
//
/////////////////////////////////////////////////////////////////////////////

int LSL_DELAY_MILLISECONDS = 30;

void lslThread() {
    if (lslStream != null) {
        lslStream.getDataFromLslStream(nchan);
    }
    delay(LSL_DELAY_MILLISECONDS);
}


//------------------------------------------------------------------------
//                       Classes
//------------------------------------------------------------------------

class LslStream {

    private int nEEGValuesPerPacket = 8;
    private int nAuxValuesPerPacket = 3;
    private DataPacket_ADS1299 rawReceivedDataPacket;
    private DataPacket_ADS1299 missedDataPacket;
    private DataPacket_ADS1299 dataPacket;

    private final float ADS1299_Vref = 4.5f;  //reference voltage for ADC in ADS1299.  set by its hardware
    private float ADS1299_gain = 24.0;  //assumed gain setting for ADS1299.  set by its Arduino code
//    private float ADS1299_gain = 1.0;  //assumed gain setting for ADS1299.  set by its Arduino code
    private float scale_fac_uVolts_per_count = ADS1299_Vref / ((float)(pow(2, 23)-1)) / ADS1299_gain  * 1000000.f; //ADS1299 datasheet Table 7, confirmed through experiment
    private final float scale_fac_accel_G_per_count = 0.002 / ((float)pow(2, 4));  //assume set to +/4G, so 2 mG per digit (datasheet). Account for 4 bits unused
    private final float leadOffDrive_amps = 6.0e-9;  //6 nA, set by its Arduino code

    private int sampleRate = 0;  // will be updated dynamically by examining the LSL stream

    private LSL.StreamInlet lslInlet = null;
    int lslChannelCount = 0;

    public float getSampleRate() {
        // TODO return computed LSL sample rate
        return 500.0;
    }

    public float get_scale_fac_uVolts_per_count() {
        return scale_fac_uVolts_per_count;
    }
    public float get_scale_fac_accel_G_per_count() {
        return scale_fac_accel_G_per_count;
    }
    public float get_leadOffDrive_amps() {
        return leadOffDrive_amps;
    }

    //constructors
    LslStream() {};  //only use this if you simply want access to some of the constants
    LslStream(PApplet applet, int nEEGValuesPerOpenBCI, int nAuxValuesPerOpenBCI) {
        initDataPackets(nEEGValuesPerOpenBCI, nAuxValuesPerOpenBCI);
    }

    public void connectToEegStream() {
        // create LSL input stream
        println("Resolving an EEG stream...");
        LSL.StreamInfo[] results = LSL.resolve_stream("type","EEG");
        println("Resolved LSL EEG stream: " + Arrays.toString(results));
        // activate input channels
        lslInlet = new LSL.StreamInlet(results[0]);
        try {
            lslChannelCount = lslInlet.info().channel_count();
            for (int i = 0; i < lslChannelCount; i++) {
                activateChannel(i);
                }
        } catch (Exception e) {
            println("Error getting LSL stream info.");
        }
    }

    public void disconnectFromEegStream() {
        println("Disconnecting from EEG stream...");
        // deactivate input channels
        try {
            lslChannelCount = lslInlet.info().channel_count();
            for (int i = 0; i < lslChannelCount; i++) {
                deactivateChannel(i);
                }
        } catch (Exception e) {
            println("Error getting LSL stream info.");
        }
        lslInlet = null;
    }

    public void initDataPackets(int _nEEGValuesPerPacket, int _nAuxValuesPerPacket) {
        nEEGValuesPerPacket = _nEEGValuesPerPacket;
        nAuxValuesPerPacket = _nAuxValuesPerPacket;
        //allocate space for data packet
        rawReceivedDataPacket = new DataPacket_ADS1299(nEEGValuesPerPacket, nAuxValuesPerPacket);  //this should always be 8 channels
        missedDataPacket = new DataPacket_ADS1299(nEEGValuesPerPacket, nAuxValuesPerPacket);  //this should always be 8 channels
        dataPacket = new DataPacket_ADS1299(nEEGValuesPerPacket, nAuxValuesPerPacket);            //this could be 8 or 16 channels
        //set all values to 0 so not null

        for (int i = 0; i < nEEGValuesPerPacket; i++) {
            rawReceivedDataPacket.values[i] = 0;
        }

        for (int i=0; i < nEEGValuesPerPacket; i++) {
            dataPacket.values[i] = 0;
            missedDataPacket.values[i] = 0;
        }
        for (int i = 0; i < nAuxValuesPerPacket; i++) {
            rawReceivedDataPacket.auxValues[i] = 0;
            dataPacket.auxValues[i] = 0;
            missedDataPacket.auxValues[i] = 0;
        }
    }


    public int closePort() {
        // TODO: finish
        // disconnect stream
        return 0;
    }

    public void syncWithHardware(int sdSetting) {
        // TODO is this needed?
    }


    public void startDataTransfer() {
    }

    public void stopDataTransfer() {
    }

    public void printRegisters() {
        // TODO print registers?
    }

    //activate or deactivate an EEG channel...channel counting is zero through nchan-1
    public void changeChannelState(int Ichan, boolean activate) {
        // TODO change channel state?
    }

    //deactivate an EEG channel...channel counting is zero through nchan-1
    public void deactivateChannel(int Ichan) {
        // TODO change channel state?
    }

    //activate an EEG channel...channel counting is zero through nchan-1
    public void activateChannel(int Ichan) {
        // TODO change channel state?
    }

    public void configureAllChannelsToDefault() {
        // TODO change channel state?
    };

    // af
    void getDataFromLslStream(int nchan) {
        float val_uV;
        float[] sample;
//        println("LSL: nchan: " + nchan);
//        println("LSL channel count: " + lslChannelCount);
        if (lslInlet != null) {
            try {
                sample = new float[lslChannelCount];
                double sample_capture_time = 0.0;
                sample_capture_time = lslInlet.pull_sample(sample);
                while (sample_capture_time != 0.0) {
                    curDataPacketInd = (curDataPacketInd + 1) % dataPacketBuff.length; // This is also used to let the rest of the code that it may be time to do something
//                    println("sample capture time: " + sample_capture_time);
                    for (int Ichan=0; Ichan < lslChannelCount; Ichan++) {
                        if (isChannelActive(Ichan)) {
                            val_uV = sample[Ichan];
//                            println("LSL: channel " + Ichan + " reading: " + val_uV);
                        } else {
//                            println("LSL: inactive channel: " + Ichan);
                            val_uV = 0.0f;
                        }
//                        dataPacketBuff[curDataPacketInd].values[Ichan] = (int) (0.5f+ val_uV / scale_fac_uVolts_per_count); //convert to counts, the 0.5 is to ensure rounding
                         // gain 1x
                        dataPacketBuff[curDataPacketInd].values[Ichan] = (int) val_uV;
//                        dataPacketBuff[curDataPacketInd].values[Ichan] = (int) (0.5f+ val_uV / scale_fac_uVolts_per_count); //convert to counts, the 0.5 is to ensure rounding
                    }
                sample_capture_time = lslInlet.pull_sample(sample);
                }
            }
            catch(Exception e) {
              println("LSL: error reading from stream!");
            }
        }
    }


};
