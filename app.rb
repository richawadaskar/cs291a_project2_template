require 'sinatra'
require 'google/cloud/storage'
require 'digest'

storage = Google::Cloud::Storage.new(project_id: 'cs291-f19')
bucket = storage.bucket 'cs291_project2', skip_lookup: true


get '/' do
  redirect "/files/"
end

def is_valid_sha256_hexdigest(string)
  # 64 length
  if string.length == 64
  # Hex

end

def is_valid_filename(name)
  # Check if slash in pos 2 and 5

  # Remove 2, 5 to obtain just filename

end

get '/files/' do
  "Get files in the bucket\n"
  files_in_bucket = bucket.list()
  print(files_in_bucket)
  files = []
  files.each do |file|
    if is_valid_filename(file.name)
      files.push file.name
    end
  end
  files = files.sort
  files = files.to_json
  body files
end


post '/files/' do
  # check if digest is valid hex 256 DIGEST
  begin
    upload_file = params['file']['tempfile']
    file_size = params['file']['tempfile'].size

    if !upload_file
      [422, "Filename not provided"]
    end

    if file_size > (1024*1024)  #1MB??
      [422, "File is too large"]
    end
  rescue
    status 422
    return
  end

  if bucket.file Digest::SHA256.hexdigest(upload_file)
    # file with same name already exists.
    [409, "File with same name already exists"]
  else
    # upload file to gcs and return response.
    sha256_digest = Digest::SHA256.hexdigest(upload_file) # is this right lol
    type = params['file']['type']
    # Add slashes
    # file = bucket.create_file sha256_digest path_in_storage, content_type: type
    [201, "uploaded: #{sha256_digest}"]
  end
end


get '/files/:DIGEST' do
  file_name = params['DIGEST']

  if is_sha256(file_name)
    [422, "Filename is not a valid hexdigest"]
    return
  end

  file = bucket.file file_name
  if file
    content_type file.content_type
    # headers content-type=file['content-type']
    [200, file['body']]
  else
    [404, "File not found"]
  end
end


delete '/files/:DIGEST' do
  file_name = params['DIGEST']

  if file_name not hexdigest
    [422, "Filename is not a valid hexdigest"]
  end

  if bucket.file file_name
    file = bucket.file file_name
    file.delete
  end

  [200, "File deleted"]
end

def is_sha256(file_name)
  if !file_name[/\H/] && file_name.length == 64
    return True
  return False
end
