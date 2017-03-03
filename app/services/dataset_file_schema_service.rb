class DatasetFileSchemaService

  def initialize(schema_name, description, url_in_s3, user)
    @schema_name = schema_name
    @description = description
    @url_in_s3 = url_in_s3
    @user = user
  end

  def create_dataset_file_schema
    Rails.logger.info "In create #{@url_in_s3}"

    @dataset_file_schema = @user.dataset_file_schemas.create(url_in_s3: @url_in_s3, name: @schema_name, description: @description)
    self.class.update_dataset_file_schema_with_json_schema(@dataset_file_schema)
    @dataset_file_schema
  end

  def self.infer_dataset_file_schema_from_csv(csv_url)
    data = CSV.parse(read_file_with_utf_8(csv_url))
    headers = data.shift
    inferer = JsonTableSchema::Infer.new(headers, data, explicit: true)
    schema = inferer.schema
  end

  def infer_and_create_dataset_file_schema(csv_url, user, schema_name, description)
    inferred_schema = self.class.infer_dataset_file_schema_from_csv(csv_url)

    url_in_s3 = upload_inferred_schema_to_s3(inferred_schema.to_json, inferred_schema_filename(schema_name))
    user.dataset_file_schemas.create(url_in_s3: url_in_s3.public_url, name: schema_name, description: description, schema: inferred_schema.to_json)
  end

  def upload_inferred_schema_to_s3(inferred_schema, filename)
    key = object_key(filename)
    obj = S3_BUCKET.object(key)
    obj.put(body: inferred_schema)
    obj
  end

  def inferred_schema_filename(schema_name)
    "#{schema_name.parameterize}.json"
  end

  def self.update_dataset_file_schema_with_json_schema(dataset_file_schema)
    Rails.logger.info "URL #{dataset_file_schema.url_in_s3}"

    dataset_file_schema.update(schema: load_json_from_s3(dataset_file_schema.url_in_s3))
  end

  def self.load_json_from_s3(url_in_s3)
    Rails.logger.info "URL #{url_in_s3}"
    JSON.generate(JSON.load(read_file_with_utf_8(url_in_s3)))
  end

  def self.read_file_with_utf_8(url)
    open(url).read.force_encoding("UTF-8")
  end

  def self.get_parsed_schema_from_csv_lint(url)
    Csvlint::Schema.load_from_json(url)
  end

  private

  def object_key(filename)
    "uploads/#{SecureRandom.uuid}/#{filename}"
  end

end