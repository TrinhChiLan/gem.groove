def updateDefaultPath(newPath)
  File.open('tcl.Assets\defaultpath.txt', 'w') do |file|
    file.write(newPath) 
    file.close
  end
end