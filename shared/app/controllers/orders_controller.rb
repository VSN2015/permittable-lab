class OrdersController < BaseController
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

  def index
    @orders = Order.includes(:customer, :items).order(:id)
  end

  def show
    @order = Order.includes(:customer, :items).find(params[:id])
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

  private

  def render_error(message:, code:, status:, errors: [])
    @violations = errors
    @order = Order.new
    render :new, status: status
  end
end
