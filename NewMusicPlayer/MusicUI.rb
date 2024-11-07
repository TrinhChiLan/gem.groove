require 'gosu'
require_relative 'FileReader.rb'

class MusicPlayer < Gosu::Window
  #
  def initialize()
    super(250, 250)
    self.caption = 'Music Player'
    getAudioFiles('tcl.Assets\Audios', 'Unassigned')
    @masterHash = getHash()
    #
    @albums = []
    @masterHash.each do |key, value|
      if key == 'Playlist' then next end
      if value.tracks.length < 1 then next end
      @albums << key
    end
    #puts @albums
    #
    @currentState = 1
    @currentAlbumIndex = 0
    #
    @currentTrackIndex = 0
    @currentTrack = nil
    @currentTrackPage = 0
    @trackButtons = []
    #
    @offPage = false #Whether or not the track index is in the page that the user is viewing.
    @paused = false
    #
    @baseFont = Gosu::Font.new(20)
    @trackFont = Gosu::Font.new(18)
    #
    @swipeSound = Gosu::Sample.new('tcl.Assets\Misc\swipe.mp3')
    @selectSound = Gosu::Sample.new('tcl.Assets\Misc\select.mp3')
  end
  def needs_cursor?; true; end
  #functions
  def currentAlbum() #get current album, duh
    return @albums[@currentAlbumIndex]
  end
  def currentAlbumTracks() #return the array of Track objects of the current album.
    return @masterHash[currentAlbum].tracks
  end
  def pauseAudio(bool) #la pause
    if !@currentTrack then return end
    @paused = bool
    bool ? @currentTrack.stop : @currentTrack.play
  end
  def playIndexedTrack()
    #If there is a currently playing track, stops it
    if @currentTrack then @currentTrack.stop end
    #
    tracks = currentAlbumTracks
    @currentTrack = Gosu::Song.new(tracks[@currentTrackIndex].location)
    @currentTrack.play 
  end
  def shift(magnitude)
    @swipeSound.play
    @currentAlbumIndex += magnitude
    if @currentAlbumIndex > @albums.length - 1 then @currentAlbumIndex = 0 end
    if @currentAlbumIndex < 0 then @currentAlbumIndex = @albums.length - 1 end
  end
  def shiftTracksPage(magnitude)
    @currentTrackPage += magnitude
    len = currentAlbumTracks.length
    if @currentTrackPage > (len/5.0).ceil - 1 then @currentTrackPage = 0 end
    if @currentTrackPage < 0 then @currentTrackPage = (len/5.0).ceil - 1 end
    if !(@currentTrackIndex >= 5*@currentTrackPage) or !(@currentTrackIndex <= 4 + 5*@currentTrackPage) then 
      puts 'User not on the same page as pointer.'
      @offPage = true
    else
      puts 'User on the same page as pointer.'
      @offPage = false
    end
    puts "Moved to page #{@currentTrackPage}" 
  end
  def shiftTrack(magnitude)
    @currentTrackIndex += magnitude
    len = currentAlbumTracks.length
    loopedBack = false
    if @currentTrackIndex > len - 1 then @currentTrackIndex = 0; loopedBack = true end
    if @currentTrackIndex < 0 then @currentTrackIndex = len - 1; loopedBack = true end
    @trackButtons[@currentTrackIndex][3] = false
    playIndexedTrack()
    #
    if (@currentTrackIndex >= 5*@currentTrackPage) and (@currentTrackIndex <= 4 + 5*@currentTrackPage) then @offPage = false end
    if @offPage then return end
    if @currentTrackIndex > 4 + 5*@currentTrackPage then 
      if loopedBack then
        @currentTrackPage = (len/5.0).ceil - 1
      else
        shiftTracksPage(1) 
      end
    end
    if @currentTrackIndex < 5*@currentTrackPage then 
      if loopedBack then
        @currentTrackPage = 0
      else
        shiftTracksPage(-1) 
      end
    end
  end
  def selectAlbum()
    @selectSound.play
    @currentState = 2
    @playingBack = true
    #
    @currentTrackIndex = 0
    tracks = currentAlbumTracks
    #(4*page)..[4 + (4*page), tracks.length - 1].min
    count = 0
    for i in 0..tracks.length - 1 do
      posX = 10
      posY = 30 + count*40
      count += 1
      if count > 4 then count = 0 end
      @trackButtons << [posX, posY, @trackFont.text_width(tracks[i].name), false]
    end
    playIndexedTrack()
    #puts @trackButtons
  end
  #Mouse interactions
  def mouseHover()
    if @currentState = 2 then
      len = currentAlbumTracks.length
      for i in (5*@currentTrackPage)..[4 + 5*@currentTrackPage, len - 1].min do
        if (mouse_x > @trackButtons[i][0] and mouse_x < @trackButtons[i][0] + @trackButtons[i][2]) and (mouse_y > @trackButtons[i][1] and mouse_y < @trackButtons[i][1] + 18) then
          if i != @currentTrackIndex then @trackButtons[i][3] = true end
        else
          @trackButtons[i][3] = false
        end
      end
    end
  end
  #
  def update()
    if @currentTrack then
      if !@currentTrack.playing? and !@paused then
        shiftTrack(1)
      end
    end
  end
  #Draw...
  def draw()
    if @currentState == 1 then
      #icon
      iconPath = @masterHash[currentAlbum].albumicon
      icon = Gosu::Image.new(iconPath)
      scaleX = 180.0/icon.width
      scaleY = 180.0/icon.height
      icon.draw(35, 15, 0, scaleX, scaleY)
      #nameNtitle
      title = @masterHash[currentAlbum].title
      titleWidth = @baseFont.text_width(title)
      @baseFont.draw_text(title, 125 - titleWidth/2, 200, 0)
      name = @masterHash[currentAlbum].artist
      nameWidth = @baseFont.text_width(name)
      @baseFont.draw_text(name, 125 - nameWidth/2, 220, 0)
    elsif @currentState == 2 then
      mouseHover
      #Drawing tracks
      tracks = currentAlbumTracks
      page = @currentTrackPage
      for i in (5*page)..[4 + (5*page), tracks.length - 1].min do
        color = Gosu::Color::WHITE
        if @trackButtons[i][3] then color = Gosu::Color::RED end
        @trackFont.draw_text(tracks[i].name, @trackButtons[i][0], @trackButtons[i][1], 0, 1, 1, color)
      end
      #Drawing indicator
      if @currentTrackIndex >= 5*@currentTrackPage and @currentTrackIndex <= 4 + 5*@currentTrackPage then
        Gosu.draw_rect(@trackButtons[@currentTrackIndex][0] - 5, @trackButtons[@currentTrackIndex][1] + 5, 5, 5, Gosu::Color::RED)
      end
    end
  end
  #Button down handler
  def pageSufficent()
    if @currentState == 1 then
      return @albums.length > 1
    else
      return (currentAlbumTracks.length/5.0).ceil > 1
    end
  end
  def button_down(id)
    case id
    when Gosu::KbRight 
      if !pageSufficent then return end
      if @currentState == 1
        shift(1)
      else
        shiftTracksPage(1)
      end      
    when Gosu::KbLeft 
      if !pageSufficent then return end
      if @currentState == 1
        shift(-1)
      else
        shiftTracksPage(-1)
      end  
    when Gosu::KB_ESCAPE 
      if @currentState == 1 then
        exit 
      elsif @currentState == 2 then
        @selectSound.play
        @currentState = 1
        @playingBack = false
        @trackButtons = []
        @currentTrackIndex = 0
        @currentTrackPage = 0
        #
        @currentTrack.stop
        @currentTrack = nil
      end
    when Gosu::KB_RETURN
      selectAlbum()
    when Gosu::KbDown
      if @currentState == 2 then shiftTrack(1) end
    when Gosu::KbUp
      if @currentState == 2 then shiftTrack(-1) end
    when Gosu::KbSpace 
      if @currentState == 2 then pauseAudio(!@paused) end
    end
  end
  #
end

MusicPlayer.new.show()