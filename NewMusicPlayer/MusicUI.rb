require 'gosu'
require_relative 'FileReader.rb'
require_relative 'FileWriter.rb'

class TextBox < Gosu::TextInput
  def initialize()
    super
    self.text = getDefaultPath()
  end
end

class SVector2
  attr_accessor :x, :y
  def initialize(x, y)
    @x = x 
    @y = y
  end
end

class Button
  attr_accessor :name, :imageObject, :position, :size
  def initialize(name, imageObject, position, size)
    @name = name
    @imageObject = imageObject
    @position = position
    @size = size
  end
end

$stateButtons = {
  '1' => [
    Button.new('Next', Gosu::Image.new('tcl.Assets\Images\Icons\next.png'), SVector2.new(225, 115), SVector2.new(20, 20)),
    Button.new('Previous', Gosu::Image.new('tcl.Assets\Images\Icons\previous.png'), SVector2.new(5, 115), SVector2.new(20, 20))
  ],
  '2' => [
    Button.new('Next', Gosu::Image.new('tcl.Assets\Images\Icons\next.png'), SVector2.new(140, 220), SVector2.new(20, 20)),
    Button.new('Previous', Gosu::Image.new('tcl.Assets\Images\Icons\previous.png'), SVector2.new(90, 220), SVector2.new(20, 20))
  ]
}

def convertToMinute(num) #THIS WILL RETURN A STRING, BEWARE
  minute = num.to_i/60
  second = num.to_i%60
  if second.to_s.length < 2 then second = "0#{second}" end
  return "#{minute}:#{second}"
end

class MusicPlayer < Gosu::Window
  #
  def initialize()
    super(250, 250)
    self.caption = 'gem.groove'
    @prompt = TextBox.new()
    self.text_input = @prompt
    #
    @masterHash = nil 
    #
    @albums = []
    @albumIconBaseSize = 180.0
    #
    @currentState = 0
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
    @timeFont = Gosu::Font.new(15)
    #Samples
    @swipeSound = Gosu::Sample.new('tcl.Assets\Misc\swipe.mp3')
    @selectSound = Gosu::Sample.new('tcl.Assets\Misc\select.mp3')
    #Initial prompt to get the path to the directory
    @enterText = "Enter Directory's path:"
    @enterTextWidth = @baseFont.text_width(@enterText)
    #Buttons  
    @pauseButton = Gosu::Image.new('tcl.Assets\Images\Icons\pause.png')
    @continueButton = Gosu::Image.new('tcl.Assets\Images\Icons\play-button-arrowhead.png')
  end
  def needs_cursor?; true; end
  #functions
  def currentAlbum() #get current album, duh
    #puts @albums[@currentAlbumIndex]
    return @albums[@currentAlbumIndex]
  end
  def currentAlbumTracks() #return the array of Track objects of the current album.
    return @masterHash[currentAlbum].tracks
  end
  def pauseAudio(bool) #la pause
    if !@currentTrack then return end
    @paused = bool
    bool ? @currentTrack.pause : @currentTrack.play
  end
  def playIndexedTrack()
    #If there is a currently playing track, stops it
    @paused = false
    @elapsedTime = 0
    @lastTick = Time.now
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
  def readPath()
    path = @prompt.text.chomp
    puts path
    if getAudioFiles(path, 'Unassigned') then
      @currentState = 1
      @masterHash = getHash()
      @masterHash.each do |key, value|
        if key == 'Playlist' then next end
        if value.tracks.length < 1 then next end
        @albums << key
      end
      self.text_input = nil
      updateDefaultPath(path)
    else
      puts 'Directory not found!'
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
    case @currentState
    when 2 
      len = currentAlbumTracks.length
      for i in (5*@currentTrackPage)..[4 + 5*@currentTrackPage, len - 1].min do
        if (mouse_x > @trackButtons[i][0] and mouse_x < @trackButtons[i][0] + @trackButtons[i][2]) and (mouse_y > @trackButtons[i][1] and mouse_y < @trackButtons[i][1] + 18) then
          if i != @currentTrackIndex then @trackButtons[i][3] = true end
        else
          @trackButtons[i][3] = false
        end
      end
    when 1
    end
  end
  def getStateButton()
    if !$stateButtons[@currentState.to_s] then return end
    for i in 0..$stateButtons[@currentState.to_s].length - 1 do
      button = $stateButtons[@currentState.to_s][i]
      if (mouse_x > button.position.x and mouse_x < button.position.x + button.size.x) and (mouse_y > button.position.y and mouse_y < button.position.y + button.size.y) then
        return button
      end
    end
    return nil
  end
  def mouseClick()
    foundStateButton = getStateButton
    if @currentState == 1 then
      #for the modulized buttons.
      if foundStateButton then 
        case foundStateButton.name
        when "Next"
          shift(1)
        when 'Previous'
          shift(-1)
        end
      end
      #others
      minX = 125 - @albumIconBaseSize/2
      maxX = minX + @albumIconBaseSize
      if (mouse_x > minX and mouse_x < maxX) and (mouse_y > 15 and mouse_y < 15 + @albumIconBaseSize) then
        selectAlbum()
      end
    elsif @currentState == 2 then
      if (mouse_x > 115 and mouse_x < 135) and (mouse_y > 220 and mouse_y < 240) then
        pauseAudio(!@paused)
      end
      if foundStateButton then 
        case foundStateButton.name
        when "Next"
          shiftTrack(1)
        when 'Previous'
          shiftTrack(-1)
        end
      end
      len = currentAlbumTracks.length
      for i in (5*@currentTrackPage)..[4 + 5*@currentTrackPage, len - 1].min do
        if @trackButtons[i][3] == true then
          puts "Pointing to #{i}"
          puts "From #{@currentTrackIndex}"
          puts i - @currentTrackIndex
          shiftTrack(i - @currentTrackIndex)
        end
      end
    end
  end
  #
  def update()
    if @currentTrack then
      if !@currentTrack.playing? and !@paused then
        shiftTrack(1)
      elsif @currentTrack.playing? and !@paused then
        currentTime = Time.now
        if currentTime - @lastTick >= 1 then
          @elapsedTime += 1
          @lastTick = currentTime
          # puts @elapsedTime
          # puts (@elapsedTime/currentAlbumTracks[@currentTrackIndex].length)*250
        end
      end
    end
  end
  #Draw...
  def draw()
    mouseHover #Mouse hover
    #$stateButtons
    if $stateButtons[@currentState.to_s] then
      for i in 0..$stateButtons[@currentState.to_s].length - 1 do
        button = $stateButtons[@currentState.to_s][i]
        button.imageObject.draw(button.position.x, button.position.y, 0, button.size.x.to_f/button.imageObject.width, button.size.y.to_f/button.imageObject.height)
      end
    end
    #State specific buttons
    if @currentState == 1 then
      #icon
      iconPath = @masterHash[currentAlbum].albumicon
      icon = Gosu::Image.new(iconPath)
      scaleX = @albumIconBaseSize/icon.width
      scaleY = @albumIconBaseSize/icon.height
      icon.draw(125 - @albumIconBaseSize/2, 15, 0, scaleX, scaleY)
      #nameNtitle
      title = @masterHash[currentAlbum].title
      titleWidth = @baseFont.text_width(title)
      @baseFont.draw_text(title, 125 - titleWidth/2, 200, 0)
      name = @masterHash[currentAlbum].artist
      nameWidth = @baseFont.text_width(name)
      @baseFont.draw_text(name, 125 - nameWidth/2, 220, 0)
    elsif @currentState == 2 then
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
        @paused ? color = Gosu::Color::BLUE : color = Gosu::Color::RED
        Gosu.draw_rect(@trackButtons[@currentTrackIndex][0] - 5, @trackButtons[@currentTrackIndex][1] + 5, 5, 5, color)
      end
      #Continue, pause button
      if @paused then
        @continueButton.draw(115, 220, 0, 20.0/@continueButton.width, 20.0/@continueButton.height)
      else
        @pauseButton.draw(115, 220, 0, 20.0/@pauseButton.width, 20.0/@pauseButton.height)
      end
      #Time elapsed
      Gosu.draw_rect(0, 245, (@elapsedTime/currentAlbumTracks[@currentTrackIndex].length)*250 , 5, Gosu::Color::WHITE)
      @timeFont.draw_text("#{convertToMinute(@elapsedTime)}/#{convertToMinute(currentAlbumTracks[@currentTrackIndex].length)}", 175, 225, 0)
    elsif @currentState == 0 then #Getting the path to the folder.
      Gosu.draw_rect(10, 110, 230, 30, Gosu::Color::GRAY)
      @baseFont.draw_text(@enterText, 125 - @enterTextWidth/2, 75, 0, 1 ,1)
      @baseFont.draw_text(@prompt.text, 12.5, 115, 0, 1, 1)
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
    when Gosu::MsLeft
      mouseClick()
    when Gosu::KB_RIGHT 
      if !pageSufficent then return end
      if @currentState == 1
        shift(1)
      elsif @currentState == 2
        shiftTracksPage(1)
      end      
    when Gosu::KB_LEFT
      if !pageSufficent then return end
      if @currentState == 1
        shift(-1)
      elsif @currentState == 2
        shiftTracksPage(-1)
      end  
    when Gosu::KB_ESCAPE 
      if @currentState == 1 or @currentState == 0 then
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
      if @currentState == 1 then
        selectAlbum()
      elsif @currentState == 0 then
        readPath()
      end
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