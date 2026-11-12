class OrdersController < BaseController
  permit_params(unknown: :error) { optional :locale, :string }

  permit_params :create, root: :order, model: Order, unknown: :error, enforce: true, desc: "Tạo đơn" do
    required :customer do
      required :name,  :string, length: 1..80, normalize: :squish
      required :email, :string, format: :email, normalize: :email
      optional :phone, :string, length: 6..20, sensitive: true
    end
    required :shipping_address do
      use ShippingAddressFields
    end
    use OrderScheduleFields
    use OrderExtrasFields
    array :items_attributes, required: true, length: 1..20 do
      required :sku, length: 1..40
      required :quantity, :integer, in: 1..99
      required :unit_price, :decimal, in: BigDecimal("0")..BigDecimal("9999.99")
    end
  end

  permit_params :update, root: :order, model: Order, unknown: :error, desc: "Sửa đơn" do
    use OrderScheduleFields, optional: true
    use OrderExtrasFields, optional: true
    optional :shipping_address do
      use ShippingAddressFields
    end
  end

  before_action :set_order, only: %i[show edit update]
  before_action :guard_closed_order, only: %i[edit update]
  before_action :record_attempted_fields, only: :update

  def index
    @orders = Order.includes(:customer, :items).order(:id)
  end

  def show
    @violations ||= []
  end

  def new
    @order = Order.new
    @violations = []
  end

  def create
    order = Order.build_from_contract(permitted_params)
    order.save!
    redirect_to order_path(order), status: :see_other
  end

  def edit
    @violations = []
  end

  def update
    @order.update!(permitted_params.to_h)
    redirect_to order_path(@order), status: :see_other,
                notice: t("lab.orders.updated", fields: @attempted.join(", "))
  end

  private

  def set_order
    @order = Order.includes(:customer, :items).find(params[:id])
  end

  def guard_closed_order
    redirect_to order_path(@order), status: :see_other, alert: t("lab.orders.closed") if @order.closed?
  end

  def record_attempted_fields
    @attempted = permitted_params.keys
  rescue Permittable::InvalidParameters
    @attempted = []
  end

  def render_error(message:, code:, status:, errors: [])
    @violations = errors
    case action_name
    when "update" then render :edit, status: status
    when "change_status" then render :show, status: status
    else
      @order = Order.new
      render :new, status: status
    end
  end
end
