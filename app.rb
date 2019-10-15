require 'sinatra'
require 'google/cloud/storage'
require 'digest'
require 'logger'
require 'json'

storage = Google::Cloud::Storage.new(project_id: 'cs291-f19')
bucket = storage.bucket 'cs291_project2', skip_lookup: true

logger = Logger.new $stdout
logger.level = Logger::INFO
Google::Apis.logger = logger

get '/' do
  logger.info "URL Matched /"
  redirect "/files/"
end


def is_valid_sha256_hexdigest(string)
  if string and string.length == 64 and !string[/\H/]
    puts "valid sha256_digest"
    return true
  end

  puts "invalid sha256_digest"
  return false
end


def is_valid_filename(name)
  begin
    if name[2] == '/' and name[5] == '/'
      puts "Slashes exist"
      name[2] = ""
      name[4] = ""
      puts "New file name is: "
      print(name)
    else
      puts "invalid path in name"
      return ""
    end
  rescue
    puts "an error occurred"
    return ""
  end

  if is_valid_sha256_hexdigest(name)
    return name
  end

  puts "not a valid sha 256 hex digest"
  return ""
end


get '/files/:digest' do
  puts "URL Matched /files/:digest"
  digest = params['digest'].downcase

  puts "Digest: "
  puts digest

  if not is_valid_sha256_hexdigest(digest)
    puts "Filename is not a valid hexdigest"
    status 422
    return
  end

  digest = add_slashes(digest)
  file = bucket.file digest

  if file
    puts "file in bucket: "
    print(file)
    downloaded_file = file.download
    downloaded_file.rewind

    content_type file.content_type
    status 200
    body downloaded_file.read
    return
  else
    status 404
    body "File not found"
    return
  end
end

def add_slashes(string)
  modified_string = string
  modified_string = modified_string.insert(2, '/')
  modified_string = modified_string.insert(5, '/')
  return modified_string
end

get '/files/' do
  puts "URL Matched /files/"
  puts "Get files in the bucket\n"
  files_in_bucket = bucket.files

  files = []
  files_in_bucket.each do |file|
    print(file.name)
    parsed_file = is_valid_filename(file.name)
    print "parsed name: "
    print(parsed_file)
    if parsed_file != ""
      files.push parsed_file
    end
  end

  files = files.sort
  files = files.to_json
  print(files)
  status 200
  body files
  return
end


post '/files/' do
  begin
    if params.key?('file')
      file = params['file']
      puts "File: "
      puts file
      if file ==  ""
        puts "File is empty"
        status 422
        return
      end
    else
      status 422
      return
    end
    puts "Getting file size: "
    if file.key?('tempfile')
      tempfile = file['tempfile']
      file_size = tempfile.size
      puts file_size
      if not tempfile or not file["filename"] or file_size > 1048576
        puts "File not provided or file too large"
        status 422
        return
      end
    else
      puts "No tempfile key found"
      status 422
      return
    end
  rescue
    puts "Caught exception"
    status 422
    return
  end

  downloaded_file = tempfile.read
  puts "downloaded_file: "
  puts downloaded_file
  digested_file = Digest::SHA256.hexdigest(downloaded_file)
  puts "digested_file: "
  puts digested_file
  file_name = add_slashes(digested_file)

  if bucket.file file_name
    puts "File with same name already exists"
    status 409
    return
  else
    puts "file head"
    puts file["head"]

    puts "tempfile path"
    puts tempfile.path

    head = file['head']
    arr = head.split("\r\n")
    content_type_str = arr[1].delete(' ')
    type = (content_type_str.split(":"))[1]
    print("type: " + type)
    file = bucket.create_file tempfile.path, file_name, content_type: type
    digested_file[2] = ""
    digested_file[4] = ""
    return_body = "{\"uploaded\": \"#{digested_file}\"}"
    puts "return_body: "
    puts return_body

    status 201
    body return_body
    return
  end
end


delete '/files/:digest' do
  file_name = params['digest'].downcase

  if not is_valid_sha256_hexdigest(file_name)
    puts "Filename is not a valid hexdigest"
    status 422
    return
  end

  file_name = add_slashes(file_name)
  file = bucket.file file_name

  if file
    file.delete
    puts "File deleted"
  end

  status 200
  return
end
