class DatasetFileSchemasController < ApplicationController

  def index
    @dataset_file_schemas = DatasetFileSchema.where(user: current_user).paginate(page: params[:page], per_page: 7).order(name: :asc)
  end

  def new
    @dataset_file_schema = DatasetFileSchema.new
    @s3_direct_post = S3_BUCKET.presigned_post(bucket_attributes)
  end

  def create
    @dataset_file_schema = DatasetFileSchema.new(create_params)
    if @dataset_file_schema.save

      DatasetFileSchemaService.update_dataset_file_schema_with_json_schema(@dataset_file_schema)
      redirect_to dataset_file_schemas_path
    else
      @s3_direct_post = S3_BUCKET.presigned_post(bucket_attributes)
      render :new
    end
  end

  private

  def bucket_attributes
    { key: "uploads/#{SecureRandom.uuid}/${filename}", success_action_status: '201', acl: 'public-read' }
  end

  def create_params
    params.require(:dataset_file_schema).permit(:name, :description, :user_id, :url_in_s3)
  end

  def dataset_params
    params.require(:dataset).permit(:name, :owner, :description, :publisher_name, :publisher_url, :license, :frequency, :schema, :schema_name, :schema_description, :dataset_file_schema_id, :restricted)
  end
end