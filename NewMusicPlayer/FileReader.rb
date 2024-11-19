require 'mp3info'

class Track
  attr_accessor :name, :location, :length
  def initialize (name, location, length)
    @name = name
    @location = location
    @length = length
  end
end

class AudioContainer
  attr_accessor :tracks
  def initialize(tracks = [])
    @tracks = tracks
  end
end

class Album < AudioContainer
  attr_accessor :title, :artist, :genre, :albumicon
  def initialize (title = 'None', artist = 'None', genre = 'None', icon = 'tcl.Assets\base.png', tracks = [])
    @title = title
    @artist = artist 
    @genre = genre 
    @albumicon = icon 
    super tracks
  end
end

class Playlist < AudioContainer
  attr_accessor :name 
  def initialize(name = 'None' , tracks = [])
    @name = name
    super tracks
  end
end

$masterHash = {
  "Unassigned" => Album.new("Unassigned"),
  "All" => Album.new("All"),
  "Playlist" => {}
}
masterDirectory = nil

def possessInfo(aFile, key)
  file = File.open(aFile, 'r')
  file.each_line do |line|
    indicator = line[0..1]
    info = line[2..line.length - 1].chomp
    if indicator == 'a.' then
      #puts "Artist: #{info}"
      $masterHash[key].artist = info
    elsif indicator == 't.' then
      #puts "Title: #{info}"
      $masterHash[key].title = info
    end
  end
end

def getAudioFiles(directory, key)
  return false if !Dir.exist?(directory)
  Dir.foreach(directory) do |child|
    next if child == '.' or child == '..' 
    path = File.join(directory, child)
    if File.directory?(path) then
      if !$masterHash[child] then $masterHash[child] = Album.new(child.chomp) end
      getAudioFiles(path, child)
    elsif File.basename(child, '.png') == 'icon' or File.basename(child, '.jpg') == 'icon' then
      $masterHash[key].albumicon = path
    elsif File.basename(child) == 'info.txt' then
      possessInfo(path, File.basename(directory))
    elsif File.extname(child) =~ /\.(mp3|wav|ogg|flac)$/i then
      exts = /\.(mp3|wav|ogg|flac)$/i
      length = Mp3Info.open(path).length
      track = Track.new(File.basename(child, '.*'), path, length)
      $masterHash[key].tracks << track
      $masterHash['All'].tracks << track
    end
  end
  return true
end

def displayHash(hash)
  hash.each do |key, value|
    if key == 'Playlist' then next end
    #puts key
    puts value.title
    puts value.artist
    puts value.tracks
  end
end

def getHash()
  return $masterHash
end

def getDefaultPath()
  defaultPath = File.open('tcl.Assets\defaultpath.txt')
  return defaultPath.gets
  defaultPath.close
end


# Replace 'audio_folder' with the actual path to your folder
# puts 'Enter the directory name!'
# direc = gets.chomp
#audio_files = getAudioFiles('tcl.Assets\Audios', 'Unassigned')
# displayHash($masterHash)
#AudioPlayer\Assets\Audios\Combat Initiation