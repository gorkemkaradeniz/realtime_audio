__author__ = 'adamjmiller'

cimport cstftmanager as cstft
import numpy as np
cimport numpy as cnp  # Get declarations in numpy.pxd
cnp.import_array()

cdef class StftManager:
    """
    Wrapper object for c realtimestft library

    This class allows for performing an STFT on data in realtime,
    as well as modifying the data's spectra in realtime.

    The length of the FFT, the length of the window, the hop size,
    the number of channels, the data type, and whether a hann
    windowing function should be used are all customizable.

    Note that the only window function available is a hann window.
    The squareroot of the hann window is applied before transforming,
    and then after transforming back from the frequency domain. If
    this is not desired, the option use_window_fcn should be set
    to False when constructing the StftManager object. (This
    will result in a rectangular window being used)

    See function descriptions for details on how to retrieve the
    spectra, and update samples.

    NOTES:
        - For the time being, this class does not allow dft's of length
        different than the window size. This is due to the fact that the
        fft's are performed in place to save time, so the input data
        must be the same length as the dft
    """
    cdef cstft.realtimeSTFT _c_stft
    cdef int _dft_length
    cdef int _window_length
    cdef int _hop_length
    cdef int _n_channels

    def __init__(self, dft_length=1024, window_length=1024, hop_length=512,
                  n_channels=1, use_window_fcn=True, dtype=np.float32):

        # Convert into log parameters for C stft library
        if not self._is_power_of_2(dft_length) or not self._is_power_of_2(window_length) or \
                not self._is_power_of_2(hop_length):
            raise ValueError("StftManager: all input parameters must be powers of 2")

        # Now convert to logs
        cdef int log_dft_length = self._log2(dft_length)
        cdef int log_window_length = self._log2(window_length)
        cdef int log_hop_length = self._log2(hop_length)

        # Check for valid dtype
        cdef int data_size
        if np.dtype(dtype) == np.dtype('float32'):
            data_size = 4
        elif np.dtype(dtype) == np.dtype('float64'):
            data_size = 8
        elif np.dtype(dtype) == np.dtype('float'):
            data_size = 8
        else:
            data_size = -1  # This way an error will occur

        # Check for valid use_window parameter
        cdef int c_use_window_fcn = 1
        if use_window_fcn == True:
            c_use_window_fcn = 1
        elif use_window_fcn == False:
            c_use_window_fcn = 0
        else:
            raise ValueError("use_window_fcn should be of boolean type.")

        # Note that self is not fully constructed at this point, so
        # don't do anything to self but assign cdef fields for now
        error = cstft.createRealtimeSTFT(&self._c_stft,
                                         log_dft_length,
                                         log_window_length,
                                         log_hop_length,
                                         n_channels,
                                         c_use_window_fcn,
                                         data_size
                                         )
        self._check_error(error)
        if &self._c_stft is NULL:
            raise MemoryError("Creation of StftManager failed.")

        # Set member variables
        self._dft_length = dft_length
        self._window_length = window_length
        self._hop_length = hop_length
        self._n_channels = n_channels
        #self._dtype = dtype


    def __dealloc__(self):
        if &self._c_stft is not NULL:
            cstft.destroyRealtimeSTFT(&self._c_stft)

    cdef _check_error(self, cstft.stft_error error):
        """
        Raise the correct exception corresponding to an error code given
        @param error: the error code returned from a call to the
                      realtimestft library
        """
        if error == cstft.STFT_FAILED_MALLOC:
            raise MemoryError("StftManager: failed malloc operation.")
        if error == cstft.STFT_INVALID_HOPSIZE:
            raise ValueError("StftManager: invalid hopsize.")
        if error == cstft.STFT_INVALID_WINDOWSIZE:
            raise ValueError("StftManager: invalid windowsize.")
        if error == cstft.STFT_INVALID_DFTLEN:
            raise ValueError("StftManager: invalid DFT length.")
        if error == cstft.STFT_INVALID_NUM_CHANNELS:
            raise ValueError("StftManager: invalid number of channels.")
        if error == cstft.STFT_NULL_PARAMETER:
            raise ValueError("StftManager: NULL parameter given.")
        if error == cstft.STFT_FFTSETUP_ERROR:
            raise ValueError("StftManager: Error in setting up FFT.")
        if error == cstft.STFT_INVALID_DATA_SIZE:
            raise ValueError("StftManager: Error in data size." +
                             " Should be 4 or 8 for float32 or float64")

    cdef bint _is_power_of_2(self, int n):
        """
        Check if a number is a power of 2
        @return: True if power of 2. False else
        """
        return n != 0 and (n & (n - 1) == 0)

    cdef int _log2(self, int n):
        """
        Get log base 2 of n. Note that it should first be
        verified that the number is a power of 2, since
        this function will only ever return an integer
        @return: floor( log base 2 of n )
        """
        cdef int count = 0
        while n != 1:
            count += 1
            n >>= 1
        return count


    cpdef performStft(self, cnp.ndarray[dtype=cnp.float32_t, mode='c'] in_data):
        """
        Perform an Stft on the given data. The data given should be
        the same length as the window length that was specified when
        creating the StftManager.

        This method will window and buffer enough segments of the input
        data, with proper overlap, so that an accurate reconstruction
        can be formed by calls to performIStft()

        Calling this function will update the set of buffered DFT's, and
        thus calls to getDFTs will provide the new set of DFT's after
        this function has completed. The DFT's can then be modified, and
        calls to performIStft() will use the modifications. However, if
        performStft() is called again before performIStft(), the changes
        to the DFT's will be overwritten by the new set of DFT's, and
        will not be apparent in the results of performIStft(), as
        performIStft() will return of reconstruction of the new data

        See getDFTs() and performIStft() for more details

        @type in_data: np.ndarray[dtype=np.float32]
        @param in_data: input data for stft
        """
        cstft.performSTFT(&self._c_stft, <cnp.float32_t *> in_data.data)

    cpdef performIStft(self):
        """
        Performs an ISTFT on the currently buffered DFT's. There are
        enough DFT's available that reconstruction with proper overlap
        can be acheived.

        Note that data obtained from successive calls to performIStft()
        (assuming calls to performStft() were made before each) will
        return data that can be output immediately after one another,
        without overlapping the data. This is because the StftManager
        will take care of all windowing and overlap.

        The DFT's used for this ISTFT will be the same as those described
        in the output of getDFTs(). See getDFTs() for details.

        @return: numpy array containing segment of istft
        """
        cdef cnp.ndarray[dtype=cnp.float32_t] out_buf = \
            np.empty(self._window_length, dtype=np.float32)
        cstft.performISTFT(&self._c_stft, <cnp.float32_t *> out_buf.data)
        return out_buf

    cpdef getDFTs(self):
        """
        Get the DFT's of each windowed segment in the current state
        of the StftManager. The DFT's of one window length of input data
        is available at all times for retrieval and modification. The
        number of DFT's that this corresponds to depends on the hopsize used
        by the StftManager.

        For example, if the hop size is half the window length, then there
        are two "hops" of data avaialable, i.e. the DFT's of two overlapping
        windows of the input data are available. For a hop size a quarter the
        length of the window, there will be four available.

        These DFT's are returned as tuple of lists. The first list in the tuple
        contains an array of real parts of the DFT's. The second list in the tuple contains
        an array of imaginary parts of the DFT. Each array in these lists will be
        half the dft length, as the input is always real, so negative frequencies
        are discarded.

        This means that the arrays in the first list and the arrays of
        the second list can be combined to make up the dft of the first windowed
        segment of the stft that is currently available for modifying.

        In the real arrays, the first element contains the DC weight, while the
        first element of the imaginary arrays contains the nyquist frequency
        weight.

        For more detail on the arrangement, see the following page (all one url):
        https://developer.apple.com/library/mac/#documentation/Performance/
        Conceptual/vDSP_Programming_Guide/UsingFourierTransforms/
        UsingFourierTransforms.html#//apple_ref/doc/uid/TP40005147-CH202-15947

        Note that these arrays represent the DFT's that will be used when
        transforming back into the time domain, so any modifications to these
        lists will have an effect on the data retrieved from calling
        performIStft().

        @return: a list containing arrays of the real and imaginary components
                 of the DFT of buffered input data. See description for details
        """
        cdef cstft.DSPSplitComplex *dft = self._c_stft.dfts
        cdef int n_dfts = self._c_stft.num_dfts
        # Lists that will hold pointers to the dft's real and imag components
        all_reals = []
        all_imags = []
        # Memory views that will hold data pointed to by realp and imagp pointers
        cdef cnp.float32_t[::1] reals
        cdef cnp.float32_t[::1] imags
        # Loop through and populate list
        for i in range(n_dfts):
            reals = <cnp.float32_t[:(self._dft_length/2)]> dft[i].realp
            imags = <cnp.float32_t[:(self._dft_length/2)]> dft[i].imagp
            all_reals.append(reals)
            all_imags.append(imags)
        return all_reals, all_imags



