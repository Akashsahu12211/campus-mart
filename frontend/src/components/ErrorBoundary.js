import React from 'react';
import './ErrorBoundary.css';

/**
 * Error Boundary Component
 * Catches rendering errors anywhere in the component tree
 * Displays fallback UI instead of blank page
 */
class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { 
      hasError: false, 
      error: null,
      errorInfo: null
    };
  }

  static getDerivedStateFromError(error) {
    // Update state so next render shows fallback UI
    return { hasError: true };
  }

  componentDidCatch(error, errorInfo) {
    // Log error details for debugging
    console.error('Error caught by boundary:', error);
    console.error('Error info:', errorInfo);
    
    this.setState({
      error: error,
      errorInfo: errorInfo
    });

    // Can also log to error reporting service here
    // logErrorToService(error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="error-boundary-container">
          <div className="error-boundary-content">
            <h1>Oops! Something went wrong</h1>
            <p>We're sorry for the inconvenience. The page encountered an error.</p>
            
            {process.env.NODE_ENV === 'development' && this.state.error && (
              <details style={{ 
                whiteSpace: 'pre-wrap', 
                marginTop: '20px',
                padding: '10px',
                backgroundColor: '#f5f5f5',
                borderRadius: '4px',
                fontSize: '12px'
              }}>
                <summary>Error Details (Development Only)</summary>
                <p>{this.state.error.toString()}</p>
                {this.state.errorInfo && (
                  <pre>{this.state.errorInfo.componentStack}</pre>
                )}
              </details>
            )}

            <div className="error-boundary-actions">
              <button 
                onClick={() => {
                  this.setState({ hasError: false, error: null, errorInfo: null });
                }}
                className="btn-retry"
              >
                Try Again
              </button>
              <button 
                onClick={() => window.location.href = '/'}
                className="btn-home"
              >
                Go to Home
              </button>
            </div>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

export default ErrorBoundary;
