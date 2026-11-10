# webrtcbin, and the SRTP and SCTP elements it uses for media and data
# channels.  AOS's image_streamer streams camera images over WebRTC.
PACKAGECONFIG:append = " webrtc srtp sctp"
