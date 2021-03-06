__author__ = 'Adam Miller'
import pyaudio

class AudioHelper(object):
    """
    Class for managing pyaudio devices. Provides extra tools
    for choosing, displaying, and managing available devices
    in conjunction with pyaudio. Also provides tools for 
    """

    def __init__(self, pa, n_channels=1):
        """
        :type pa: pyaudio.PyAudio
        :param pa: pyaudio.PyAudio object for use in determining devices
        """
        if not isinstance(pa, pyaudio.PyAudio):
            raise ValueError("pa must be a pyaudio.PyAudio object")
        self._pa = pa
        self._n_channels = n_channels

    def get_device_names(self):
        """
        Returns a list with the names of the available devices. The
        devices position in the list indicates the device's index

        :return: list withe available device names
        """
        return [self._pa.get_device_info_by_index(i)['name']
                for i in range(self._pa.get_device_count())]

    def get_device_input_channels(self):
        """
        Returns a list with the maximum input channels of all the
        available devices. The device position indicates the device's
        index

        :return: list with device input channel counts
        """
        return [self._pa.get_device_info_by_index(i)['maxInputChannels']
                for i in range(self._pa.get_device_count())]

    def get_device_info_by_name(self, name):
        """
        Returns dictionary with device info for the device with
        the given name. Is case insensitive to 'name' input

        :param name: name of the desired
        :return: dictionary with device info for the device with the
                given name if such a device exists. None otherwise
        """
        self._pa.get_device_info_by_index(2)
        devices = [self._pa.get_device_info_by_index(i) for i in range(self._pa.get_device_count())]
        for device in devices:
            if device['name'].lower() == name.lower():
                return device

    def display_input_devices(self):
        """
        Prints the avaiable devices to the console, with each name
        preceded by its associated device index
        """
        for i in range(self.get_device_count()):
            info = self.get_device_info_by_index(i)
            print str(i) + ": " + info['name'] + " -- " + \
                    str(info['maxInputChannels']) + " input channels"

    def display_output_devices(self):
        """
        Prints the available output devices to the console, with each
        name preceded by its associated device index
        """
        for i in range(self.get_device_count()):
            info = self.get_device_info_by_index(i)
            print str(i) + ": " + info['name'] + " -- " + \
                  str(info['maxOutputChannels']) + " output channels"

    def get_input_device_from_user(self):
        """
        Presents a prompt that allows the user to choose
        one of the available input devices
        """
        print "Select an input device"
        print "======================"
        self.display_input_devices()
        chosen = False
        in_device = self.get_default_input_device_info()
        while not chosen:
            try:
                choice = int(raw_input())
                in_device = self.get_device_info_by_index(choice)
                chosen = True
            except IOError as e:
                print "Please enter a valid device index"
            except ValueError as e:
                print "Input must be a device index number"
        return in_device

    def get_output_device_from_user(self):
        """
        Presents a prompt that allows the user to choose
        one of the available output devices
        """
        print "Select an ouput device"
        print "======================"
        self.display_output_devices()
        chosen = False
        out_device = self.get_default_output_device_info()
        while not chosen:
            try:
                choice = int(raw_input())
                out_device = self.get_device_info_by_index(choice)
                chosen = True
            except IOError as e:
                print "Please enter a valid device index"
            except ValueError as e:
                print "Input must be a device index number"
        return out_device

    def get_device_count(self):
        """
        Wrapper for pyaudio.PyAudio method with same name
        """
        return self._pa.get_device_count()

    def get_default_input_device_info(self):
        """
        Wrapper for pyaudio.PyAudio method with same name
        """
        return self._pa.get_default_input_device_info()

    def get_default_output_device_info(self):
        """
        Wrapper for pyaudio.PyAudio method with same name
        """
        return self._pa.get_default_output_device_info()

    def get_device_info_by_index(self, index):
        """
        Wrapper for pyaudio.PyAudio method with same name
        """
        return self._pa.get_device_info_by_index(index)


